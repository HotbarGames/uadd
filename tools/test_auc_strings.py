"""Checks UADD_Auctionator's Ukrainian (ui/locale.lua, ui/text.lua) against the installed Auctionator.

The repo keeps none of Auctionator's English: these tests read it from the installed addon at test time
(tools/make_auc_text.py finds it: AUCTIONATOR_DIR, $UADD_ADDONS_DIR/Auctionator or the game folder).
Without it, the tests that need it are skipped.
- enUS.lua can be read; every ns.UA key is one of its keys, once; each Ukrainian keeps its English's
  % slots, | codes, line breaks (a written \\n counts as one, as Auctionator's AddNewLines and Words.lua
  read it) and leading or trailing space; the auction lengths keep their 12 / 24 / 48 (and 2 / 8);
  the dates' words are in the right form;
- ns.UA_MADE: its keys are enUS keys, the code still joins / changes them that way, and the Ukrainian
  fits the English made from them;
- ui/text.lua: every hash is a text Auctionator's code still writes, and the file is what
  make_auc_text.py build makes from the review file (so each template fits its English);
- review then build gives back the same ui/locale.lua; the readers and build on made-up files.

python3 -m unittest tools.test_auc_strings
"""
import re
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import glossary  # noqa: E402
import hashtext  # noqa: E402
import luatok  # noqa: E402
import make_auc_text as M  # noqa: E402
from coverage import compatible, escape_counts  # noqa: E402

LOCALE = M.LOCALE
ADDON = M.addon_dir()
ENUS = ADDON / "Locales" / "enUS.lua"
HAVE_ADDON = ENUS.is_file()
SKIP = f"Auctionator not installed in {ADDON} (set AUCTIONATOR_DIR)"
CODE_DIRS = ("Source", "Source_ModernAH", "Source_Forever", "Source_Mainline")
SPEC = re.compile(r"%[-+ #0]*\d*\.?\d*[sdif]|%%")
DIGITS = {"AUCTION_DURATION_12": "12", "AUCTION_DURATION_24": "24", "AUCTION_DURATION_48": "48"}


def read_locale(path, name="UA"):
    """{name: [(key, uk or None, glossary id or None, line)]}: the entries of ns.<name> (`["key"] = "uk"`,
    `["key"] = G"id"`, `KEY = G"id"`). [] when the table or the file is not there."""
    out = {name: []}
    path = Path(path)
    if not path.is_file():
        return out
    t = list(luatok.tokens(luatok.read(path)))
    head = [(luatok.NAME, "ns"), (luatok.SYM, "."), (luatok.NAME, name), (luatok.SYM, "="), (luatok.SYM, "{")]
    inside, depth, i = False, 0, 0
    while i < len(t):
        if not inside:
            if [x[:2] for x in t[i:i + 5]] == head:
                inside, depth, i = True, 1, i + 5
                continue
            i += 1
            continue
        if t[i][:2] == (luatok.SYM, "{"):
            depth += 1
        elif t[i][:2] == (luatok.SYM, "}"):
            depth -= 1
            if depth == 0:
                break
        elif depth == 1:
            key, j = None, None
            if t[i][:2] == (luatok.SYM, "[") and i + 3 < len(t) and t[i + 1][0] == luatok.STR \
                    and t[i + 2][:2] == (luatok.SYM, "]") and t[i + 3][:2] == (luatok.SYM, "="):
                key, j = t[i + 1][1], i + 4
            elif t[i][0] == luatok.NAME and i + 1 < len(t) and t[i + 1][:2] == (luatok.SYM, "=") \
                    and t[i - 1][:2] in ((luatok.SYM, ","), (luatok.SYM, "{")):
                key, j = t[i][1], i + 2
            if key is not None and j < len(t):
                if t[j][0] == luatok.STR:
                    out[name].append((key, t[j][1], None, t[i][2]))
                else:
                    out[name].append((key, None, glossary._ref_at(t, j), t[i][2]))
                i = j + 1
                continue
        i += 1
    return out


def read_made(path=LOCALE):
    """ns.UA_MADE's entries as dicts: {"join": [a, b] | "key", "from", "to", "uk"}."""
    text = Path(path).read_text(encoding="utf-8") if Path(path).is_file() else ""
    body = text.split("ns.UA_MADE = {", 1)[1] if "ns.UA_MADE = {" in text else ""
    out = []
    for line in body.splitlines():
        if not line.strip().startswith("{"):
            continue
        rec = {k: M.unquote(v) for k, v in re.findall(r'\b(key|from|to|uk) = ("(?:[^"\\]|\\.)*")', line)}
        for name, keys in re.findall(r'\b(join|lines) = \{ ([^}]*) \}', line):
            rec[name] = re.findall(r'"([A-Z0-9_]+)"', keys)
        out.append(rec)
    return out


def made_en(rec, enus):
    """The English Auctionator makes for a UA_MADE entry (as Words.lua makes it), or None."""
    keys = rec.get("join") or rec.get("lines")
    if keys:
        ens = [enus.get(k, (None,))[0] for k in keys]
        return None if None in ens else " ".join(ens) if "join" in rec else "\n".join(e + " %s" for e in ens)
    en = enus.get(rec.get("key"), (None,))[0]
    return en.replace(rec["from"], rec["to"]) if en is not None else None


def breaks(text):
    return text.replace("\\n", "\n").count("\n")


def code_files():
    """{file: its text} of Auctionator's code."""
    out = {}
    for d in CODE_DIRS:
        for p in sorted((ADDON / d).rglob("*.lua")) if (ADDON / d).is_dir() else []:
            out[p] = luatok.read(p)
    return out


@unittest.skipUnless(HAVE_ADDON, SKIP)
class LocaleAgainstAuctionator(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.enus, cls.bad = M.read_enus(ADDON)
        cls.loc = read_locale(LOCALE)
        g = glossary.Glossary()
        cls.pairs = []   # (key, English or None, Ukrainian, line)
        for key, uk, gid, line in cls.loc["UA"]:
            en = cls.enus[key][0] if key in cls.enus else None
            cls.pairs.append((key, en, uk if gid is None else g.text(gid), line))

    def test_enus_read(self):
        self.assertEqual(self.bad, [], "enUS.lua lines make_auc_text.py cannot read")
        self.assertGreater(len(self.enus), 400)

    def test_keys_known_and_once(self):
        names = [k for k, *_ in self.loc["UA"]]
        self.assertGreater(len(names), 300)
        self.assertEqual(sorted(k for k in set(names) if names.count(k) > 1), [], "keys twice")
        self.assertEqual([(k, line) for k, en, _, line in self.pairs if en is None], [], "not an enUS.lua key")

    def test_slots_codes_breaks_spaces(self):
        for key, en, uk, line in self.pairs:
            if en is None:
                continue
            with self.subTest(key=key, line=line):
                self.assertTrue(uk, "empty, or a glossary id that is not there")
                uk = uk.replace("\\n", "\n")
                if SPEC.search(en):
                    self.assertTrue(compatible(en, uk), f"{uk!r}: other % slots or | codes than the English")
                else:
                    self.assertEqual((escape_counts(en), en.count("%")), (escape_counts(uk), uk.count("%")),
                                     f"{uk!r}: other | codes or % signs")
                self.assertEqual(breaks(en), breaks(uk), "other number of line breaks")
                self.assertEqual((en[:1] == " ", en[-1:] == " "), (uk[:1] == " ", uk[-1:] == " "),
                                 "leading/trailing space differs")

    def test_lengths_keep_their_digits(self):
        for key, en, uk, line in self.pairs:
            if key in DIGITS and uk:
                with self.subTest(key=key):
                    self.assertRegex(uk, r"(?<!\d)" + DIGITS[key] + r"(?!\d)")
        for rec in read_made():
            if "to" in rec:
                with self.subTest(made=rec["key"]):
                    self.assertRegex(rec["uk"], r"(?<!\d)" + rec["to"] + r"(?!\d)")

    def test_date_words(self):
        # Words.lua turns "weekday, month day" into "Вівторок, 25 лютого": the months must be in
        # the "of" form (лютого, not лютий) and the weekdays start with a capital letter.
        ua = {key: uk for key, en, uk, line in self.pairs}
        for i in range(1, 13):
            with self.subTest(key=f"MONTH_{i}"):
                self.assertRegex(ua.get(f"MONTH_{i}", ""), r"^[а-яіїєґ']+(ня|ого|да)$",
                                 "a month in the \"of\" form, lower case")
        for i in range(1, 8):
            with self.subTest(key=f"DAY_{i}"):
                uk = ua.get(f"DAY_{i}", "")
                self.assertTrue(uk[:1].isupper() and uk[1:] == uk[1:].lower(), f"{uk!r}: capitalised weekday")

    def test_made_texts(self):
        made = read_made()
        self.assertEqual(len(made), 10)
        files = code_files()
        self.assertTrue(files)
        for rec in made:
            with self.subTest(made=rec.get("join") or rec.get("lines") or rec.get("key")):
                en = made_en(rec, self.enus)
                self.assertIsNotNone(en, "a key that enUS.lua no longer has")
                if "key" not in rec:
                    ns = ["AUCTIONATOR_L_" + k + (' .. " " .. ' if "lines" in rec else "") for k in rec.get("join") or rec["lines"]]
                    self.assertTrue(any(all(n in t for n in ns) for t in files.values()), "no longer joined in the code")
                else:
                    call = f'gsub("{rec["from"]}", "{rec["to"]}")'
                    self.assertTrue(any(call in t for t in files.values()), f"no {call} in the code")
                if SPEC.search(en):
                    self.assertTrue(compatible(en, rec["uk"]), "other % slots or | codes than the English")


@unittest.skipUnless(HAVE_ADDON, SKIP)
class CodeTexts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.found = M.all_code_texts(ADDON)
        cls.data = M.read_text_lua()

    def test_hashes_are_texts_of_the_code(self):
        keys = {hashtext.key(en) for _, en in self.found}
        self.assertGreater(len(self.data), 20)
        self.assertEqual([k for k in self.data if k not in keys], [],
                         "no longer in Auctionator's code: run tools/make_auc_text.py review, then build")

    def test_text_lua_is_what_build_makes(self):
        # Also checks every template: hashtext.template() refuses a Ukrainian that does not fit.
        entries = [("CODE", hashtext.key(en), M.esc(en), M.esc(M.uk_text(en, self.data[hashtext.key(en)])))
                   for _, en in self.found if hashtext.key(en) in self.data]
        self.assertEqual(M.build_text_lua(entries), M.TEXT_LUA.read_text(encoding="utf-8"),
                         "ui/text.lua is not what tools/make_auc_text.py build makes")

    def test_review_then_build_keeps_locale(self):
        text, _ = M.review_text(ADDON)
        entries = M.parse_review(text)
        self.assertGreater(sum(1 for e in entries if e[0] == "KEY"), 400)
        locale = LOCALE.read_text(encoding="utf-8")
        self.assertEqual(M.build_locale(entries, locale), (locale, []))
        self.assertEqual(M.build_text_lua(entries), M.TEXT_LUA.read_text(encoding="utf-8"))


FIXTURE = '''local _, ns = ...
local G = function() end
ns.UA = {
    ["ONE"] = "Один",
    TWO = G"game.level",
    ["THREE"] = "Три %s/%s у\\\\n %s",
    ["NESTED"] = ({ "a" })[1],
}
ns.UA_MADE = {
    { join = { "ONE", "TWO" }, uk = "Разом: %s" },
    { key = "THREE", from = "12", to = "2", uk = "2 год" },
}
'''
CODE = '''local WRONG = "Bad thing %s here"
local rows = { { commands = "x", message = "Does a thing." } }
Auctionator.Utilities.Message("Done now.")
Auctionator.Utilities.Message("Item " .. name .. ": " .. tostring(v))
Auctionator.Utilities.Message(name .. ": " .. v)
Auctionator.Debug.Message("Never shown")
print(BLUE:WrapTextInColorCode("Label: "))
'''


class Offline(unittest.TestCase):
    def test_reader_partial_file(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "locale.lua"
            p.write_text(FIXTURE, encoding="utf-8")
            got, made = read_locale(p), read_made(p)
        self.assertEqual([(k, uk, gid) for k, uk, gid, _ in got["UA"]],
                         [("ONE", "Один", None), ("TWO", None, "game.level"),
                          ("THREE", "Три %s/%s у\\n %s", None), ("NESTED", None, None)])
        self.assertEqual(breaks(got["UA"][2][1]), 1)
        self.assertEqual(made, [{"uk": "Разом: %s", "join": ["ONE", "TWO"]},
                                {"key": "THREE", "from": "12", "to": "2", "uk": "2 год"}])
        self.assertEqual(made_en(made[1], {"THREE": ("12 x", "")}), "2 x")

    def test_reader_no_file(self):
        self.assertEqual(read_locale(Path(tempfile.gettempdir()) / "no-such-locale.lua"), {"UA": []})

    def test_code_texts(self):
        # Help texts, Utilities.Message (a join as a %s template; one with too few own bytes left out),
        # a colour-wrapped label and a local format string; never Debug.Message.
        self.assertEqual(M.code_texts(CODE), ["Bad thing %s here", "Does a thing.", "Done now.",
                                              "Item %s: %s", "Label: "])

    def test_build_locale(self):
        text = FIXTURE.replace("\\\\n", "\\n")
        entries = [("KEY", "ONE", "x", "Перший"), ("KEY", "TWO", "y", 'G"game.level"'),
                   ("KEY", "FOUR", "z", "Чотири"), ("KEY", "FIVE", "w", ""), ("CODE", "1:00000000", "a", "б")]
        out, warn = M.build_locale(entries, text)
        self.assertIn('    ["ONE"] = "Перший",', out)
        self.assertIn('    ["FOUR"] = "Чотири",\n}', out)
        self.assertNotIn("FIVE", out)
        self.assertEqual(warn, [])
        _, warn = M.build_locale([("KEY", "TWO", "y", "Інше")], text)
        self.assertEqual(len(warn), 1)

    def test_review_round_trip(self):
        review = '# note\n\n[KEY ONE]\nen: One \\"x\\"\nuk: Один\n\n[CODE 9:00000000 a.lua]\nen: Item %s: %s\nuk: Річ %s: %s\n'
        entries = M.parse_review(review)
        self.assertEqual(entries[0], ("KEY", "ONE", 'One \\"x\\"', "Один"))
        out = M.build_text_lua(entries)
        self.assertIn('uk = { "Річ ", 1, ": ", 2 }', out)
        self.assertEqual(M.uk_text("Item %s: %s", M.parse_text_lua(out)[hashtext.key("Item %s: %s")]),
                         "Річ %s: %s")


if __name__ == "__main__":
    unittest.main()
