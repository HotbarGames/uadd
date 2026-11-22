"""tools/make_dci_text.py, tools/dci_source.py and tools/dci_rules.py (with tools/key_text.py): which L keys are rows,
the join rows, drafts, FIT, the checks, the data files, and no English of DeleteCheapestItem Reloaded in our files.
Made-up English only; tests that read the installed addon skip when it is missing."""
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import dci_rules as R  # noqa: E402
import dci_source as S  # noqa: E402
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import luatok  # noqa: E402
import make_dci_text as M  # noqa: E402

ADDON = S.addon_dir()
INSTALLED = (ADDON / S.TOC).is_file()
MOD = ROOT / "UADD_DeleteCheapestItem"
OURS = [TOOLS / "make_dci_text.py", TOOLS / "dci_rules.py", TOOLS / "dci_source.py", TOOLS / "test_dci_text.py"]
LUA = r'''
local L = DCI.L
print(L["Wobbly gizmo"], L["Plain 100%"])
print(L["Chat gizmo: "] .. name)
print(L["Paren gizmo"] .. " " .. (price or "none"))
print(L["Tail gizmo"] .. "x")
print(L["Wobbly gizmo"] .. " " .. "more")
local s = "Not an L gizmo"
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
        self.d = Path(self.dir.name)
        write(self.d, "DeleteCheapestItem.lua", LUA)
        write(self.d, "Profiles.lua", 'print(L["Second gizmo"])\n')
        write(self.d, S.TOC, "## Version: 9.9\nDeleteCheapestItem.lua\n")

    def tearDown(self):
        self.dir.cleanup()

    def test_lookups_and_joins(self):
        got = {en: join for en, _, join in S.lookups(self.d / "DeleteCheapestItem.lua")}
        self.assertEqual(got["Chat gizmo: "], "%s")
        self.assertEqual(got["Paren gizmo"], " %s")
        self.assertEqual(got["Tail gizmo"], "")           # glued to a text, not to a name
        self.assertEqual(got["Plain 100%"], "")
        self.assertNotIn("Not an L gizmo", got)            # only L["..."] is a row

    def test_rows(self):
        rows, why = S.source(self.d)
        ens = [r[1] for r in rows]
        self.assertEqual(ens, ["Wobbly gizmo", "Plain 100%", "Chat gizmo: ", "Paren gizmo", "Tail gizmo", "Second gizmo"])
        self.assertTrue(all(r[0] == code(r[1]) for r in rows))
        self.assertEqual([r[2] for r in rows], [1, 1, 1, 1, 1, 2])
        self.assertEqual(len(rows[0][3]), 2)               # the same key twice: one row, two places
        self.assertEqual(why, {})
        self.assertEqual(S.version(self.d), "9.9")
        self.assertEqual(S.source(self.d / "missing"), ([], {}))

    def test_join_rows_only_when_named(self):
        self.assertNotIn("Chat gizmo: %s", [r[1] for r in S.source(self.d)[0]])
        with mock.patch.dict(R.JOINS, {code("Chat gizmo: "): "%s", code("Paren gizmo"): " %s"}):
            rows, _ = S.source(self.d)
            ens = [r[1] for r in rows]
            self.assertIn("Chat gizmo: %s", ens)
            self.assertIn("Paren gizmo %s", ens)
            self.assertNotIn("Tail gizmo%s", ens)
        with mock.patch.dict(R.JOINS, {code("Paren gizmo"): "%s"}):    # the glue must match what the code does
            self.assertNotIn("Paren gizmo%s", [r[1] for r in S.source(self.d)[0]])


class Rules(unittest.TestCase):
    def test_keep(self):
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
        self.assertEqual(R.check(k, "|cffffd200Wobbly|r gizmo", "|cffffd200Хиткий|r гвинтик"), [])
        self.assertTrue(R.check(k, "Wobbly\ngizmo", "Хиткий гвинтик"))
        self.assertTrue(R.check(k, "Wobbly gizmo", "Хиткий |Tгвинтик"))
        self.assertTrue(R.check(k, "Wobbly: ", "Хиткий:"))                       # the code glues a name after the space
        self.assertTrue(R.check(k, "Wobbly:", "Хиткий: "))
        self.assertEqual(R.check(k, "Wobbly: ", "Хиткий: "), [])

    def test_font_marks(self):
        k = code("x")
        self.assertTrue(R.check(k, "Wobbly gizmo", "Хиткий · гвинтик"))
        self.assertTrue(R.check(k, "Wobbly gizmo", "• Хиткий гвинтик"))
        self.assertEqual(R.check(k, "Wobbly gizmo", "Хиткий — гвинтик"), [])

    def test_fit(self):
        self.assertTrue(R.FIT)
        for key, (where, width) in R.FIT.items():
            self.assertEqual(R.fit_max(key), width // 6 - 1, key)
            ok, long = "а" * R.fit_max(key), "а" * (R.fit_max(key) + 1)
            self.assertEqual(R.check(key, "Wobbly", ok), [], key)
            refused = R.check(key, "Wobbly", long)
            self.assertTrue(any("too long" in p for p in refused), key)
            self.assertIn(f"{R.fit_max(key)} letters", R.note(key, "DeleteCheapestItem.lua"))
        self.assertEqual(R.fit_max("Code.7c8c4ef5"), 60 // 6 - 1)      # the 60 px main window button: 9 letters
        self.assertEqual(R.check("Code.7c8c4ef5", "Delete", "Видалити"), [])    # 8 letters fit

    def test_rule_keys(self):
        for key, letters in R.SORTS.items():
            self.assertRegex(key, r"^Code\.[0-9a-f]{8}$")
            self.assertRegex(letters, r"^[vtfn]+$", key)

    def test_join_tables(self):
        self.assertEqual(set(R.JOINED.values()), set(R.JOINS))
        self.assertEqual(len(R.JOINED), len(R.JOINS))
        self.assertTrue(set(R.JOINS.values()) <= {"%s", " %s"})
        for jkey, part in R.JOINED.items():
            self.assertNotEqual(jkey, part)
            self.assertIn(jkey, R.SORTS, jkey)                 # the join row's slot has a letter
            self.assertEqual(len(R.SORTS[jkey]), 1)

    def test_batches(self):
        self.assertEqual((R.batch_of("DeleteCheapestItem.lua"), R.batch_of("Profiles.lua"), R.batch_of("Broker.lua")),
                         (1, 2, 2))
        self.assertEqual([b[0] for b in R.BATCHES], [1, 2])
        with self.assertRaises(SystemExit):
            R.split([row("g%d" % i) for i in range(R.MAX_BATCH + 1)])


class Drafts(unittest.TestCase):
    ROWS = [row('Wobbly "gizmo"'), row("Two\nlines"), row("Plain gizmo", 2), row("Bent gizmo ", 2), row("Left gizmo", 2)]
    DRAFT = ("# made-up\nEN: Wobbly \\\"gizmo\\\"\nUA: Хиткий «гвинтик»\n\nEN: Two\\nlines\nUA: Два\\nрядки\n\n"
             "EN: Plain gizmo\nUA: Простий гвинтик\n\nEN: Bent gizmo\nUA: Зігнутий гвинтик\n\nEN: Left gizmo\nUA: \n\n"
             "EN: Nowhere gizmo\nUA: Ніде\n")

    def test_fills(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "draft_01.txt", self.DRAFT)
            fills, unmatched = M.draft_fills(self.ROWS, d)
        k = [r[0] for r in self.ROWS]
        self.assertEqual((fills[k[0]], fills[k[1]], fills[k[2]]), ("Хиткий «гвинтик»", "Два\nрядки", "Простий гвинтик"))
        self.assertNotIn(k[3], fills)                           # exact only: the row has a trailing space
        self.assertNotIn(k[4], fills)                           # an empty UA fills nothing ...
        self.assertEqual(unmatched, ["Bent gizmo", "Nowhere gizmo"])   # ... but names its row
        self.assertEqual(M.draft_key("Wobbly gizmo"), code("Wobbly gizmo"))

    def test_space_fills(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "draft_01.txt", "EN: Bent gizmo\nUA: Зігнутий\n\nEN: Plain gizmo\nUA: Ні\n\nEN: Gone gizmo\nUA: Де\n")
            fills, left = M.space_fills(self.ROWS, ["Bent gizmo", "Plain gizmo", "Gone gizmo"], d)
        self.assertEqual(fills, {self.ROWS[3][0]: "Зігнутий "})   # only a row whose English is the EN + one space
        self.assertEqual(left, ["Plain gizmo", "Gone gizmo"])

    def test_join_fills(self):
        rows = [row("Wobbly name:"), row("Wobbly name:%s"), row("50% gizmo"), row("50%% gizmo%s")]
        joined = {code("Wobbly name:%s"): code("Wobbly name:"), code("50%% gizmo%s"): code("50% gizmo")}
        joins = {code("Wobbly name:"): "%s", code("50% gizmo"): "%s"}
        with mock.patch.dict(R.JOINED, joined, clear=True), mock.patch.dict(R.JOINS, joins, clear=True), \
                tempfile.TemporaryDirectory() as d:
            K.review(M.SPEC, rows, d)
            self.assertEqual(M.join_fills(d), {})               # no UA in the part: nothing to copy
            p = K.review_files(d)[0]
            write(d, p.name, p.read_text(encoding="utf-8").replace(
                "EN: 50% gizmo\nUA: ", "EN: 50% gizmo\nUA: Піввідсотка 50% ", 1))
            self.assertEqual(M.join_fills(d), {code("50%% gizmo%s"): "Піввідсотка 50%% %s"})

    def test_round_trip(self):
        """review -> drafts fill only empty UAs -> build -> data files; a rerun keeps every UA."""
        with tempfile.TemporaryDirectory() as d:
            K.review(M.SPEC, self.ROWS, d)
            p = Path(d) / "review_02.txt"
            write(d, "review_02.txt", p.read_text(encoding="utf-8").replace(
                "EN: Plain gizmo\nUA: ", "EN: Plain gizmo\nUA: Мій гвинтик", 1))
            write(d, "draft_01.txt", self.DRAFT)
            sizes, gone, filled, unmatched = M.review(self.ROWS, d)
            self.assertEqual((sizes, gone, filled), ({1: 2, 2: 3}, 0, 3))   # 2 + the space fill; Plain keeps its own
            self.assertEqual(unmatched, ["Nowhere gizmo"])
            M.review(self.ROWS, d)
            rev = K.read_all(d)
            self.assertEqual(rev[self.ROWS[2][0]][1], "Мій гвинтик")        # the review's own UA wins
            self.assertEqual(rev[self.ROWS[3][0]][1], "Зігнутий гвинтик ")
            entries, res = K.build(M.SPEC, self.ROWS, None, d)
            self.assertEqual((res["done"], res["left"], res["bad"]), (4, 1, []))
            out = Path(d) / "data"
            K.write_data(M.SPEC, entries, "0", out, files=M.FILES)
            t, _ = data_entries(out)
            self.assertEqual(t[self.ROWS[0][0]], "Хиткий «гвинтик»")
            self.assertEqual(len(list(out.glob("text*.lua"))), M.FILES)
            head = (out / "text01.lua").read_text(encoding="utf-8")
            for line in ("local _, ns = ...", "local T = ns.T or {}; ns.T = T", "local S = ns.SORT or {}; ns.SORT = S"):
                self.assertIn(line + "\n", head)
            for p in out.glob("text*.lua"):
                self.assertNotIn("gizmo", p.read_text(encoding="utf-8"), p.name)   # only hashes and ours


@unittest.skipUnless(INSTALLED, "DeleteCheapestItem Reloaded is not installed")
class Installed(unittest.TestCase):
    rows, why = S.source(ADDON) if INSTALLED else ([], {})
    every = [en for f in S.FILES if (ADDON / f).is_file() for en, *_ in S.lookups(ADDON / f)] if INSTALLED else []

    def test_rows(self):
        keys = {code(en) for en in self.every}
        self.assertTrue(self.rows)
        self.assertEqual(len({r[0] for r in self.rows}), len(self.rows))
        self.assertTrue(all(r[0] == code(r[1]) for r in self.rows))
        self.assertTrue(all(r[2] in (1, 2) for r in self.rows))
        self.assertNotEqual(S.version(ADDON), "?")
        for r in self.rows:
            if r[0] not in keys:
                self.assertIn(r[0], R.JOINED, r[0])             # a row that is no L key is a join row

    def test_rule_keys_are_real(self):
        keys = {code(en) for en in self.every}
        for k in list(R.SORTS) + list(R.NOTES) + list(R.CODE) + list(R.FIT) + list(R.JOINS):
            if k not in R.JOINED:
                self.assertIn(k, keys, k)

    def test_sorts_fit_and_joins(self):
        rows = {k: en for k, en, *_ in self.rows}
        for key, en, *_ in self.rows:
            self.assertNotIn(None, R.sorts(key, en), key)
        for key, letters in R.SORTS.items():
            self.assertIn(key, rows, key)                       # every slot mark names a real row ...
            self.assertEqual(len(letters), len(K.slots(rows[key])), key)   # ... with that many slots
        for key in R.FIT:
            self.assertIn(key, rows, key)
        for jkey, part in R.JOINED.items():
            self.assertIn(jkey, rows, jkey)
            self.assertEqual(rows[jkey], rows[part].replace("%", "%%") + R.JOINS[part], jkey)

    def test_no_english_in_our_files(self):
        ens = {en for _, en, *_ in self.rows if len(en.strip()) > 3}
        for p in OURS + sorted(MOD.rglob("*.lua")) + sorted(MOD.glob("*.toc")):
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
            self.assertEqual(R.check(key, rows[key], ua), [], key)
            self.assertEqual(s.get(key, ""), "".join(R.sorts(key, rows[key])), key)
        self.assertEqual(set(s) - set(t), set())
        for n in range(1, M.FILES + 1):
            self.assertTrue((MOD / "data" / f"text{n:02d}.lua").is_file(), n)


if __name__ == "__main__":
    unittest.main()
