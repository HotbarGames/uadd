"""tools/make_wql_text.py, tools/wql_source.py and tools/wql_rules.py (with tools/key_text.py): which texts are rows,
the checks, the round trip to the data file, and no English of Wowhead Quick Link in our files. Made-up English
only; tests that read the installed addon skip when it is missing."""
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
import make_wql_text as M  # noqa: E402
import wql_rules as R  # noqa: E402
import wql_source as S  # noqa: E402

ADDON = S.addon_dir()
INSTALLED = (ADDON / S.MAIN).is_file()
MOD = ROOT / "UADD_WowheadQuickLink"
OURS = [TOOLS / "make_wql_text.py", TOOLS / "wql_rules.py", TOOLS / "wql_source.py", TOOLS / "test_wql_text.py",
        TOOLS / "drift_wql.py"]
MAIN = '''
local popupText = "%s wobbly gizmo"
StaticPopupDialogs["GIZMO"] = { button1 = "Shut", text = popupText }
'''
STRAT = '''
local function a(x) return 5, "gizmo" end
local function b(x) return 7, "npc" end
local function c() return "Wobbly gizmo shop", 3 end
local function d() return "Gizmoverse", 4 end
local function e(t) local h = "Gizmohead: " .. typeStr return h end
'''
CONFIG = '''
BINDING_HEADER_GIZMO = "Gizmo header"
BINDING_NAME_GIZMO_WOBBLE = "Wobble the gizmo"
'''
XML = '''<Ui>
  <FontString name="Gizmo_Title" text="Gizmo &amp; settings"/>
  <FontString name="WowheadQuickLinkConfig_FinalUrlText" text="http://gizmo"/>
  <FontString name="Gizmo_Empty"/>
</Ui>
'''


def write(folder, name, text):
    (Path(folder) / name).write_text(text, encoding="utf-8")


def stand_in(folder):
    for name, text in ((S.MAIN, MAIN), (S.STRAT, STRAT), (S.CONFIG, CONFIG), (S.XML, XML),
                       (S.TOC, "## Version: 9.9\n")):
        write(folder, name, text)


def data_entries(folder):
    """({key: Ukrainian}, {key: sorts}) of the data files, read as Lua tokens."""
    t, s = {}, {}
    for p in sorted(Path(folder).glob("text*.lua")):
        tok = list(luatok.tokens(luatok.read(p)))
        for i in range(len(tok) - 5):
            if tok[i][0] == luatok.NAME and tok[i][1] in ("T", "S") and tok[i + 1][1] == "[" \
                    and tok[i + 2][0] == luatok.STR and tok[i + 4][1] == "=" and tok[i + 5][0] == luatok.STR:
                (t if tok[i][1] == "T" else s)[tok[i + 2][1]] = tok[i + 5][1]
    return t, s


class Source(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        stand_in(self.dir.name)
        self.rows, self.why = S.source(Path(self.dir.name))

    def tearDown(self):
        self.dir.cleanup()

    def test_rows(self):
        got = {key: en for key, en, *_ in self.rows}
        want = {"%s wobbly gizmo": "Pop.", "Shut": "Code.", "Gizmo": "Type.", "Gizmohead: %s": "Head.",
                "Wobble the gizmo": "Code.", "Gizmo & settings": "Code."}
        self.assertEqual(got, {pre + H.djb2(en): en for en, pre in want.items()})
        self.assertTrue(all(r[2] == 1 for r in self.rows))

    def test_left_out(self):
        self.assertEqual(self.why, {R.AS_IS: 2, "a whole header: stays English": 1})
        self.assertEqual(S.kept_as_is(Path(self.dir.name)), {H.djb2("NPC"), H.djb2("Gizmoverse")})
        self.assertEqual(S.version(Path(self.dir.name)), "9.9")
        self.assertEqual(S.source(Path(self.dir.name) / "missing"), ([], {}))

    def test_cap(self):
        self.assertEqual((S.cap("npc"), S.cap("gizmo"), S.cap("")), ("NPC", "Gizmo", ""))


class Rules(unittest.TestCase):
    def test_keep(self):
        self.assertEqual(R.keep("whole", "Gizmoverse"), (False, R.AS_IS))
        self.assertEqual(R.keep("whole", "Wobbly shop"), (False, "a whole header: stays English"))
        self.assertEqual(R.keep("type", "NPC"), (False, R.AS_IS))
        self.assertEqual(R.keep("label", "  "), (False, "empty"))
        self.assertEqual(R.keep("label", "%d%%"), (False, "no words"))
        self.assertEqual(R.keep("label", "Wobbly gizmo"), (True, ""))
        self.assertEqual(R.keep("type", "Gizmo"), (True, ""))

    def test_sorts(self):
        self.assertEqual(R.sorts("Pop.x", "%s wobbly gizmo"), ["t"])
        self.assertEqual(R.sorts("Head.x", "Gizmo: %s"), ["t"])
        self.assertEqual(R.sorts("Code.x", "Wobbly gizmo"), [])

    def test_check(self):
        self.assertEqual(R.check("Code.x", "Wobbly gizmo", "Хиткий гвинтик"), [])
        self.assertEqual(R.check("Type.x", "Gizmo", "гвинтик"), [])
        self.assertTrue(R.check("Type.x", "Gizmo", "Гвинтик"))                  # follows the header's colon
        self.assertEqual(R.check("Head.x", "Gizmo %s link", "Gizmo: %s"), [])   # a site name and a colon
        self.assertTrue(R.check("Head.x", "Gizmo %s link", "Gizmo: %s %s"))
        self.assertEqual(R.check("Pop.x", "%s wobbly\ngizmo", "%s: хиткий\nгвинтик"), [])
        self.assertTrue(R.check("Pop.x", "%s wobbly\ngizmo", "%s: хиткий гвинтик"))     # lines
        self.assertTrue(R.check("Pop.x", "%s wobbly gizmo", "%s хиткий %s"))            # one slot
        self.assertTrue(R.check("Pop.x", "%s wobbly gizmo", "хиткий гвинтик"))
        self.assertTrue(R.check("Code.x", "Wobbly gizmo", "Хиткий — гвинтик"))
        self.assertTrue(R.check("Code.x", "Wobbly gizmo", "Хиткий · гвинтик"))

    def test_notes_and_batches(self):
        self.assertEqual(set(R.NOTES), {"popup", "button", "head", "type", "binding", "label"})
        self.assertEqual([b[0] for b in R.BATCHES], [1])
        self.assertEqual(R.batch_of("Code.x"), 1)


class RoundTrip(unittest.TestCase):
    def test_review_build_data(self):
        """review -> UAs typed in -> build -> the data file holds only hashes and ours; a rerun keeps every UA."""
        with tempfile.TemporaryDirectory() as d:
            stand_in(d)
            rows, _ = S.source(Path(d))
            K.review(M.SPEC, rows, d)
            p = Path(d) / "review_01.txt"
            text = p.read_text(encoding="utf-8")
            for en, ua in (("%s wobbly gizmo", "%s: хиткий гвинтик"), ("Shut", "Закрити"), ("Gizmo", "гвинтик"),
                           ("Wobble the gizmo", "Хитнути гвинтик")):
                text = text.replace(f"EN: {K.esc(en)}\nUA: \n", f"EN: {K.esc(en)}\nUA: {ua}\n", 1)
            p.write_text(text, encoding="utf-8")
            K.review(M.SPEC, rows, d)
            self.assertEqual(K.read_all(d)[S.key_of("button", "Shut")][1], "Закрити")
            entries, res = K.build(M.SPEC, rows, None, d)
            self.assertEqual((res["done"], res["left"], res["bad"]), (4, 2, []))
            out = Path(d) / "data"
            K.write_data(M.SPEC, entries, "0", out, files=M.FILES)
            t, s = data_entries(out)
            self.assertEqual(t[S.key_of("popup", "%s wobbly gizmo")], "%s: хиткий гвинтик")
            self.assertEqual(s[S.key_of("popup", "%s wobbly gizmo")], "t")
            head = (out / "text01.lua").read_text(encoding="utf-8")
            self.assertIn("local T = ns.AL or {}; ns.AL = T\n", head)
            self.assertNotIn("gizmo", head.lower().replace("гвинтик", ""))       # only hashes and ours


@unittest.skipUnless(INSTALLED, "Wowhead Quick Link is not installed")
class Installed(unittest.TestCase):
    rows, why = S.source(ADDON) if INSTALLED else ([], {})

    def test_every_row_built(self):
        t, s = data_entries(MOD / "data")
        rows = {k: en for k, en, *_ in self.rows}
        self.assertEqual(set(t), set(rows))
        for key, ua in t.items():
            self.assertRegex(key, r"^(Pop|Head|Type|Code)\.[0-9a-f]{8}$")
            self.assertEqual(R.check(key, rows[key], ua), [], key)
            self.assertEqual(s.get(key, ""), "".join(R.sorts(key, rows[key])), key)
        self.assertEqual(set(s) - set(t), set())

    def test_kinds_found(self):
        kinds = {k.split(".")[0] for k, *_ in self.rows}
        self.assertEqual(kinds, {"Pop", "Head", "Type", "Code"})
        self.assertTrue(S.kept_as_is(ADDON))

    def test_no_english_in_our_files(self):
        # a Head row's words are a site name and a colon: our Ukrainian keeps them as they are
        ens = {en for k, en, *_ in self.rows if len(en.strip()) > 3 and not k.startswith("Head.")}
        files = OURS + sorted(MOD.rglob("*.lua")) + sorted(MOD.glob("*.toc"))
        for p in files:
            text = p.read_text(encoding="utf-8")
            for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', text):      # the message names the hash, not the text
                lit = K.unesc(m.group(1))
                self.assertFalse(lit in ens, f"{p.name}: its English ({H.djb2(lit)})")
            for line in text.splitlines():
                if line.lstrip().startswith(("--", "#")):
                    for en in ens:
                        if len(en.split()) >= 3:
                            self.assertFalse(en in line, f"{p.name}: its English in a comment ({H.djb2(en)})")


if __name__ == "__main__":
    unittest.main()
