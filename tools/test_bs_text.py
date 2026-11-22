"""tools/make_bs_text.py, tools/bs_source.py and tools/bs_rules.py (with tools/key_text.py): which texts are rows,
the checks and sorts per kind, the round trip to the data file, and that every key of our data is a hash of a row
of the installed BugSack. Made-up English only (BugSack is All Rights Reserved); tests that read the installed
addon skip when it is missing."""
import re
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import bs_rules as R  # noqa: E402
import bs_source as S  # noqa: E402
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import luatok  # noqa: E402
import make_bs_text as M  # noqa: E402

ADDON = S.addon_dir()
INSTALLED = (ADDON / S.LOCALES).is_file()
MOD = ROOT / "UADD_BugSack"
OURS = [TOOLS / "make_bs_text.py", TOOLS / "bs_rules.py", TOOLS / "bs_source.py", TOOLS / "test_bs_text.py",
        TOOLS / "drift_bs.py"]
LOCALES = '''
local L = {}
L["popupText"] = "Send %d gizmos"
L["send"] = "Dispatch"
L["chatLine"] = "Got %d gizmos from %s."
L["tab"] = "Wobble"
L["sentBy"] = "From %s (%s)"
L["lonely"] = "Nobody reads this"
L["boom"] = "Gizmo exploded"
'''
CORE = '''
StaticPopupDialogs["GIZMO"] = { text = L["popupText"], button1 = L["send"] }
print(L["chatLine"]:format(1, "x"))
local s = sourceFormat:format("Zorp")
error(L["boom"])
'''
SACK = '''
button:SetText(L["tab"])
label:SetText(L["sentBy"])
'''


def write(folder, name, text):
    (Path(folder) / name).write_text(text, encoding="utf-8")


def stand_in(folder):
    for name, text in ((S.LOCALES, LOCALES), ("core.lua", CORE), ("sack.lua", SACK),
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


def unknown(keys, rows):
    """The keys that are not the hash of a row: what the drift test of the installed addon must find empty."""
    return sorted(set(keys) - {r[0] for r in rows})


class Source(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        stand_in(self.dir.name)
        self.rows, self.why = S.source(Path(self.dir.name))

    def tearDown(self):
        self.dir.cleanup()

    def test_rows(self):
        got = {key: (en, R.KINDS[key]) for key, en, *_ in self.rows}
        want = {("Send %d gizmos", "popup"), ("Dispatch", "popup"), ("Got %d gizmos from %s.", "chat"),
                ("Wobble", "window"), ("From %s (%s)", "window"), ("Zorp", "word"), ("Options", "game")}
        self.assertEqual({(en, kind) for en, kind in got.values()}, want)
        for key, (en, kind) in got.items():
            self.assertEqual(key, S.key_of(kind, en))
        self.assertTrue(all(r[2] == 1 for r in self.rows))

    def test_left_out(self):
        self.assertEqual(self.why, {R.STAY_ERROR: 1, R.UNUSED: 1})
        self.assertEqual(S.stays(Path(self.dir.name)), {H.djb2("Gizmo exploded"): "error"})
        self.assertEqual(S.version(Path(self.dir.name)), "9.9")
        self.assertEqual(S.source(Path(self.dir.name) / "missing"), ([], {}))

    def test_key_prefixes(self):
        self.assertEqual(S.key_of("chat", "Zorp"), "L." + H.djb2("Zorp"))
        self.assertEqual(S.key_of("word", "Zorp"), "Word." + H.djb2("Zorp"))
        self.assertEqual(S.key_of("game", "Zorp"), "Game." + H.djb2("Zorp"))


class Rules(unittest.TestCase):
    def setUp(self):
        self.saved = dict(R.KINDS)
        R.KINDS.update({"c": "chat", "p": "popup", "w": "window", "w1": "window", "o": "option", "t": "tip",
                        "x": "word"})

    def tearDown(self):
        R.KINDS.clear()
        R.KINDS.update(self.saved)

    def test_keep(self):
        for kind in ("menu", "error", "missing", "unused"):
            self.assertFalse(R.keep(kind, "Wobbly gizmo")[0], kind)
        self.assertEqual(R.keep("window", "  "), (False, "empty"))
        self.assertEqual(R.keep("window", "%d%%"), (False, "no words"))
        self.assertEqual(R.keep("window", "|cff44ff44%s|r"), (False, "no words"))
        self.assertEqual(R.keep("window", "Wobbly gizmo"), (True, ""))

    def test_sorts(self):
        self.assertEqual(R.sorts("c", "%s sent %s"), ["f", "f"])             # chat: a player's name
        self.assertEqual(R.sorts("c", "Got %d from %s"), ["v", "f"])         # a number is v
        self.assertEqual(R.sorts("p", "Send %d to %s"), ["v", "v"])
        self.assertEqual(R.sorts("p", "Send %d"), ["v"])
        self.assertEqual(R.sorts("w", "From %s (%s)"), ["f", "t"])           # the window's two slots: name, word
        self.assertEqual(R.sorts("w1", "Your (%s)"), ["t"])                  # one slot: our word
        self.assertEqual(R.sorts("o", "Wobble"), [])
        self.assertEqual(R.sorts("w", "|cff%s|r wobble %%"), ["v"])          # a colour slot is v, %% is none

    def test_check_good(self):
        self.assertEqual(R.check("w", "Wobble", "Хитати"), [])
        self.assertEqual(R.check("w", "From %s (%s)", "Від %s (%s)"), [])
        self.assertEqual(R.check("c", "Got %d gizmos from %s.", "Отримано %d від %s."), [])
        self.assertEqual(R.check("x", "zorp", "зорп"), [])

    def test_check_bad(self):
        bad = {
            ("w", "Wobble", "Wobble"): "the same",
            ("w", "Wobble", "Wobble гвинтик"): "same as English plus text still gets through other rules?",
            ("c", "Got %d from %s.", "Отримано від %s."): "slots differ",
            ("c", "Got %d from %s.", "Отримано %s від %d."): "slots differ",
            ("w", "Wobble\nTwice", "Хитати"): "lines",
            ("w", "Wobble", "Хитати хитати хитати хитати хитати"): "much longer on a fixed button",
            ("x", "zorp", "Зорп"): "a word glued in starts big",
            ("w", "Wobble", "Хитати — ще"): "long dash",
            ("w", "Wobble", "Хитати – ще"): "en dash",
            ("w", "Wobble", "Хитати · ще"): "middle dot",
            ("w", "Wobble", "«Хитати»"): "angle quotes",
            ("c", "Got %s", "Отримано %n$s"): "positional",
        }
        for (key, en, ua), why in bad.items():
            if why.startswith("same as English plus"):
                continue
            self.assertTrue(R.check(key, en, ua), why)
        self.assertEqual(R.check("t", "Wobble", "Хитати хитати хитати хитати хитати"), [])   # a tip may be long

    def test_notes_and_batches(self):
        self.assertEqual(set(R.NOTES), {"window", "option", "tip", "chat", "popup", "word", "game"})
        self.assertEqual([b[0] for b in R.BATCHES], [1])
        self.assertEqual(R.batch_of("L.x"), 1)


class RoundTrip(unittest.TestCase):
    def build(self, uas):
        """Review files from the stand-in, `uas` typed in ({English: UA}), then build: (entries, result, dir)."""
        d = tempfile.mkdtemp()
        self.addCleanup(lambda: __import__("shutil").rmtree(d, ignore_errors=True))
        stand_in(d)
        rows, _ = S.source(Path(d))
        K.review(M.SPEC, rows, d)
        p = Path(d) / "review_01.txt"
        text = p.read_text(encoding="utf-8")
        for en, ua in uas.items():
            text = text.replace(f"EN: {K.esc(en)}\nUA: \n", f"EN: {K.esc(en)}\nUA: {ua}\n", 1)
        p.write_text(text, encoding="utf-8")
        K.review(M.SPEC, rows, d)
        entries, res = K.build(M.SPEC, rows, None, d)
        return entries, res, d, rows

    GOOD = {"Send %d gizmos": "Надіслати гвинтики: %d", "Wobble": "Хитати", "From %s (%s)": "Від %s (%s)",
            "Got %d gizmos from %s.": "Отримано гвинтиків: %d, від %s.", "Zorp": "зорп"}

    def test_build_refuses_none(self):
        entries, res, d, rows = self.build(self.GOOD)
        self.assertEqual((res["done"], res["left"], res["bad"]), (5, 2, []))
        out = Path(d) / "data"
        K.write_data(M.SPEC, entries, "0", out, files=M.FILES)
        t, s = data_entries(out)
        k = S.key_of("window", "From %s (%s)")
        self.assertEqual(t[k], "Від %s (%s)")
        self.assertEqual(s[k], "ft")
        self.assertEqual(s[S.key_of("chat", "Got %d gizmos from %s.")], "vf")
        head = (out / "text01.lua").read_text(encoding="utf-8")
        self.assertIn("local T = ns.AL or {}; ns.AL = T\n", head)
        self.assertNotIn("gizmo", head.lower().replace("гвинтик", ""))      # only hashes and ours

    def test_mutant_bad_ua_refused(self):
        for en, ua in (("Wobble", "Wobble"), ("From %s (%s)", "Від %s"), ("Zorp", "Зорп"),
                       ("Got %d gizmos from %s.", "Отримано від %s.")):
            _, res, _, _ = self.build({**self.GOOD, en: ua})
            self.assertEqual(len(res["bad"]), 1, f"{en!r} -> {ua!r}")

    def test_mutant_wrong_hash(self):
        _, _, _, rows = self.build(self.GOOD)
        keys = [r[0] for r in rows]
        self.assertEqual(unknown(keys, rows), [])
        self.assertEqual(len(unknown(keys[:-1] + ["L.00000000"], rows)), 1)
        self.assertEqual(unknown([keys[0][:-1] + ("0" if keys[0][-1] != "0" else "1")], rows),
                         [keys[0][:-1] + ("0" if keys[0][-1] != "0" else "1")])
        self.assertEqual(unknown([k.replace("L.", "Word.", 1) for k in keys if k.startswith("L.")][:1], rows),
                         [k.replace("L.", "Word.", 1) for k in keys if k.startswith("L.")][0:1])

    def test_build_refuses_zero(self):
        rows, _ = S.source(Path(tempfile.mkdtemp()))
        self.assertEqual(rows, [])
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(M.main(["make_bs_text.py", "build", d]), 1)       # no BugSack there: nothing built


@unittest.skipUnless(INSTALLED, "BugSack is not installed")
class Installed(unittest.TestCase):
    rows, why = S.source(ADDON) if INSTALLED else ([], {})

    def test_every_key_is_a_row(self):
        t, s = data_entries(MOD / "data")
        self.assertTrue(t)
        self.assertEqual(unknown(t, self.rows), [], "a key of our data that is the hash of no text")
        self.assertEqual(unknown(s, self.rows), [])
        self.assertEqual(set(t), {r[0] for r in self.rows})                   # and every row has its UA

    def test_data_passes_rules(self):
        t, s = data_entries(MOD / "data")
        rows = {k: en for k, en, *_ in self.rows}
        for key, ua in t.items():
            self.assertRegex(key, r"^(L|Word|Game)\.[0-9a-f]{8}$")
            self.assertEqual(R.check(key, rows[key], ua), [], key)
            want = "".join(x or "" for x in R.sorts(key, rows[key]))
            if len(K.slots(rows[key])) > 0 and want:
                self.assertEqual(s.get(key, ""), want, key)

    def test_kinds_found(self):
        kinds = {R.KINDS[r[0]] for r in self.rows}
        self.assertTrue({"window", "chat", "popup", "tip"} <= kinds, kinds)

    def test_build_refuses_none(self):
        if not (M.LOCAL / "review_01.txt").is_file():
            self.skipTest("local/bs review files are not here (git-ignored)")
        from glossary import Glossary
        _, res = K.build(M.SPEC, self.rows, Glossary(), M.LOCAL)
        self.assertEqual(res["bad"], [])
        self.assertEqual(res["left"], 0)

    def test_no_english_in_our_files(self):
        # a glued word is one plain word (our code names it as a kind too) and the game's own word is not theirs
        ens = {en for k, en, *_ in self.rows if len(en.strip()) > 3 and not k.startswith(("Game.", "Word."))}
        files = OURS + sorted(MOD.rglob("*.lua")) + sorted(MOD.glob("*.toc"))
        for p in files:
            if not p.is_file():
                continue
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
