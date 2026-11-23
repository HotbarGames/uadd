"""Checks UADD_ForeverXPBar/data/words.lua against the installed ForeverXP Bar.

- data/words.lua is what tools/make_fxpb_data.py builds from the addon now and from its own Ukrainian
  (run the tool after an addon update), and nothing in it was left out as unfit;
- the texts the tool finds hold nothing that must stay English: addon messages (FXPB), the FXPBGlobal
  channel, event names, theme ids, font flags, paths, slash-only help lines, debug output, the game
  chat lines the addon reads back, the addon's own name; each text is listed once;
- every template has a slot; a few known texts are there, and every fxpb_rules.JOINED recipe still
  finds all its pieces;
- each Ukrainian keeps its English's % slots, | codes and the spaces at its ends;
- data/words.lua keeps one record per line (the tool reads it back without a Lua parser);
- the scanner, the rules and the data writer work on a small made-up addon (no game folder needed).

ForeverXP Bar is not in this repo: it is read from the game folder, or from the path in FXPB_DIR.
Without it, the tests that need it are skipped. The known texts are given by their hash keys only.

python3 -m unittest tools.test_fxpb_strings
"""
import re
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fxpb_words as W  # noqa: E402
import glossary  # noqa: E402
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import make_fxpb_data as M  # noqa: E402
from coverage import compatible, escape_counts  # noqa: E402

HAVE_ADDON = M.have_addon()

# Hash keys (hashtext.key) of texts that must stay English: the addon's messages, channel and names,
# theme ids, font flags, frame types, a game chat line it reads back, saved-setting words.
STAY = {"10:b5edbda6", "12:5308eb38", "12:a591ba3b", "12:b382e5d0", "13:57b5d71b", "20:33a342e9", "42:ede34980",
        "4:7c84f2f5", "4:7c94415e", "4:7c953e80", "4:7c97710b", "4:7c9aa20e", "5:0d31e1b0", "5:0f97c4d7",
        "6:00033fd6", "6:aa5a4961", "7:36d2e308", "7:71f05091", "7:9159d265", "7:cb8e8f87", "8:5699f445",
        "8:7dc6d75e"}
# Some texts that must be found: three labels and three templates (race code, flight time, error line).
MUST_HAVE = {("exact", "13:31708c51"), ("exact", "21:e6303353"), ("exact", "8:ee507a83"),
             ("format", "22:1cb05d92"), ("format", "35:8eeefe7c"), ("format", "57:e6ae55c5")}


@unittest.skipUnless(HAVE_ADDON, f"ForeverXP Bar not found in {M.addon_dir()} (set FXPB_DIR)")
class Data(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.kept, cls.skipped = M.collect()
        cls.texts = M.texts(cls.kept)
        cls.data = M.DATA.read_text(encoding="utf-8")
        cls.source = "\n".join(luatok.read(M.addon_dir() / f) for f in M.FILES if (M.addon_dir() / f).exists())

    def test_in_sync_with_the_addon(self):
        text, problems, _ = M.build()
        self.assertEqual(problems, [], "texts whose Ukrainian does not fit")
        self.assertEqual(self.data, text, "data/words.lua is out of date: run python3 tools/make_fxpb_data.py")

    def test_each_text_once(self):
        self.assertEqual(len(self.texts), len(set(self.texts)))
        self.assertGreater(len(self.texts), 400)

    def test_known_texts_are_there(self):
        self.assertLessEqual(MUST_HAVE, {(k, H.key(t)) for k, t in self.texts})
        gone = [where for why, _, where in self.skipped if why == "gone"]
        self.assertEqual(gone, [], "a JOINED recipe lost a piece: check fxpb_rules.JOINED")

    def test_nothing_that_must_stay_english(self):
        events = set(re.findall(r'RegisterEvent\(\s*"([A-Z_]+)"', self.source))
        self.assertTrue(events)
        bad = []
        for n, (kind, s) in enumerate(self.texts, 1):
            why = (H.key(s) in STAY and "stays English") or (s in events and "event") \
                or (re.match(r"\[?FXPB", s) and "addon message") \
                or (re.search(r"\\|\.(tga|blp|ttf|ogg)\b|^Interface", s, re.I) and "path") \
                or (re.fullmatch(r"[A-Z][A-Z0-9]*_[A-Z0-9_]+|[a-z]+[A-Z]\w*|#?[0-9A-Fa-f]{6}", s) and "identifier") \
                or (re.match(r"/fxpb [\w|/<> ]*$", s) and "slash only") \
                or (R_DEBUG.match(s) and "debug") \
                or (re.fullmatch(r"(\|c[0-9a-fA-F]{8}|\|r|%[-.\d]*[sd]|\W)*", s) and "no words")
            if why:
                bad.append(f"#{n} {why}: {H.key(s)}")   # #n: the number in local/foreverxpbar.txt
        self.assertEqual(bad, [])

    def test_whats_new_page_left_out(self):
        """The What's New page stays English: the addon still has both marks of its range, its texts are
        left out ("news"), and no kept text is found only inside it."""
        news = M.news_lines(luatok.read(M.addon_dir() / M.MAIN))
        self.assertGreater(len(news), 50, "the What's New marks (fxpb_rules.NEWS_START/END) are gone: find the page again")
        self.assertGreaterEqual(sum(why == "news" for why, _, _ in self.skipped), 10)
        inside = [H.key(t) for rows in self.kept.values() for _, t, where in rows
                  if all((m := re.fullmatch(r"L(\d+)", w)) and int(m[1]) in news for w in where)]
        self.assertEqual(inside, [])

    def test_templates_have_slots(self):
        no_slot = [H.key(s) for kind, s in self.texts if kind == "format" and not H.is_template(s)]
        self.assertEqual(no_slot, [])

    def test_free_and_blank_slots_are_the_addons(self):
        """Each FREE / BLANK key is one of the addon's templates and names %s slots it has, and
        data/words.lua carries them (a stale key would make a name slot strict again)."""
        kinds = {H.key(en): W.own(en)["kinds"] for kind, en in self.texts if kind == "format"}
        for name, table in (("FREE", W.FREE), ("BLANK", W.BLANK)):
            for key, slots in table.items():
                with self.subTest(table=name, key=key):
                    self.assertIn(key, kinds)
                    self.assertTrue(all(1 <= k <= len(kinds[key]) and kinds[key][k - 1] == "s" for k in slots))
        self.assertEqual(self.data.count(" free = { "), len(W.FREE))

    def test_ukrainian_keeps_slots_codes_and_spaces(self):
        g = glossary.Glossary()
        for kind, en in self.texts:
            value = W.text_of(W.ukrainian([(kind, en)], self.data).get(en), g)
            if not value:
                continue
            with self.subTest(key=H.key(en)):
                if kind == "format":
                    self.assertTrue(compatible(en, value), "other % slots or | codes")
                else:   # an exact text is never formatted: its % is a plain sign, kept as is
                    self.assertEqual((escape_counts(en), en.count("%")), (escape_counts(value), value.count("%")),
                                     "other | codes or % signs")
                self.assertEqual((en[:1] == " ", en[-1:] == " "), (value[:1] == " ", value[-1:] == " "),
                                 "leading/trailing space differs")


R_DEBUG = re.compile(r"(REP|FLIGHT|QUEST|GLOBAL) DEBUG|GLOBAL PEERS|settings check|watched: ")


class DataFile(unittest.TestCase):
    def test_one_record_per_line(self):
        text = M.DATA.read_text(encoding="utf-8")
        exact, templates = W.read(text)
        body = text.split("    templates = {\n", 1)[1].split("\n    },\n", 1)[0].split("\n")
        self.assertGreater(len(exact), 300)
        self.assertEqual(len(templates), len(body), "a template that read() cannot parse")
        self.assertTrue(all(W.KEY.fullmatch(k) for k in exact))


FIXTURE = r'''
local f = CreateFrame("Frame", nil, UIParent)
f:RegisterEvent("PLAYER_LEVEL_UP")
local SOUND = "Interface\\AddOns\\ForeverXPbar\\Sound\\x.ogg"
local function printMsg(m) DEFAULT_CHAT_FRAME:AddMessage("|cff8ee6deForeverXP Bar|r " .. m) end
label:SetText("Show Pie Slice")
printMsg("depth set to " .. tostring(w) .. ".")
printMsg(string.format("%d hops, %.1f%% done", n, p))
printMsg(("%s apples"):format(q))
C_ChatInfo.SendAddonMessage("FXPB", "H|" .. payload, "PARTY")
SendChatMessage("[FXPB]" .. msg, "CHANNEL", nil, id)
if db.cardTheme == "alliance" then x = 1 end
local opts = { { text = "Off", value = "off" }, { text = "Quarters", value = "quarters" } }
if cmd == "repdebug" then
    printMsg("REP DEBUG: id=" .. tostring(id))
    printMsg("watched faction")
end
local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S or "Nobody called '%s' is here."
local match = msg:match("You gain (%d+) experience")
printMsg("10% of " .. n)
'''


class Fixture(unittest.TestCase):
    def test_scanner_and_rules(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / M.MAIN).write_text(FIXTURE, encoding="utf-8")
            kept, skipped = M.collect(d)
        got = {(k, t) for a, rows in kept.items() if a != "joined" for k, t, _ in rows}
        self.assertEqual(got, {("exact", "Show Pie Slice"), ("format", "depth set to %s."),
                               ("format", "%d hops, %.1f%% done"), ("format", "%s apples"),
                               ("exact", "Off"), ("exact", "Quarters"), ("format", "10%% of %s")})
        reasons = {it.text: why for why, it, _ in skipped}
        self.assertEqual(reasons["REP DEBUG: id=%s"], "debug")
        self.assertEqual(reasons["watched faction"], "debug")
        self.assertEqual(reasons["FXPB"], "protocol")
        self.assertEqual(reasons["Nobody called '%s' is here."], "code")
        self.assertEqual(reasons["alliance"], "code")
        self.assertEqual(reasons["PLAYER_LEVEL_UP"], "code")

    def test_news_page_range(self):
        page = 'label:SetText("Show Pie Slice")\nlocal notice = Fx._newBox(UIParent, 1)\nt:SetText("Big news")\n' \
               'openFeatureGuide = function()\nb:SetText("Big news")\nc:SetText("Old news")\n'
        self.assertEqual(M.news_lines(page), {2, 3, 4})
        self.assertEqual(M.news_lines(page.replace("openFeatureGuide", "other")), set())
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / M.MAIN).write_text(page, encoding="utf-8")
            kept, skipped = M.collect(d)
        got = {t: where for rows in kept.values() for _, t, where in rows}
        self.assertEqual(got.get("Big news"), ["L5"], "a text also used outside the page is kept from there")
        self.assertIn("Old news", got)
        self.assertIn(("news", "Big news"), {(why, it.text) for why, it, _ in skipped})

    def test_data_round_trip(self):
        texts = [("exact", "Show Pie Slice"), ("exact", "Off"), ("format", "%d hops, %.1f%% done"),
                 ("format", "%s apples and %s pears"), ("format", "depth set to %s.")]
        uk = {"Show Pie Slice": '"Показати шматок"', "Off": '"Вимк."', "%d hops, %.1f%% done": '"%d стрибків, %.1f%% готово"',
              "%s apples and %s pears": '"%2$s груш і %1$s яблук"', "depth set to %s.": ""}
        data, problems = W.build(texts, uk, glossary.Glossary())
        self.assertEqual(problems, [])
        text = W.write(data, "test")
        self.assertNotIn("apples", text)
        self.assertNotIn("hops", text)
        self.assertEqual(W.ukrainian(texts, text), {k: v for k, v in uk.items() if v})
        self.assertEqual(len(data["known"]), 2)
        self.assertEqual(len(data["long"]), 3)

    def test_review_round_trip(self):
        kept = {a[0]: [] for a in M.AREAS}
        kept["bar"] = [["exact", "Show Pie Slice", ["L1"]], ["format", 'say "%s"\n', ["L2"]]]
        uk = {"Show Pie Slice": '"Показати шматок"', 'say "%s"\n': '"скажіть «%s»\\n"'}
        self.assertEqual(M.read_review(M.write_review(kept, uk, "test")), uk)
