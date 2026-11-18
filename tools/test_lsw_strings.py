"""Checks UADD_LayerSwap/data/words.lua against the installed LayerSwap.

- data/words.lua is what tools/make_lsw_data.py builds from the addon now and from its own Ukrainian
  (run the tool after an addon update), and nothing in it was left out as unfit;
- the texts the tool finds hold nothing that must stay English: its chat channel and addon-message
  words, the whisper asking for an invite and its variants, the game's refusal lines it reads back,
  event names, paths, slash-only help lines, the addon's own name; each text is listed once;
- every template has a slot and a few known texts are there;
- each Ukrainian keeps its English's % slots, | codes and the spaces at its ends;
- the texts of the panel's fixed boxes (status box, host line) are not much longer than the English;
- data/words.lua keeps one record per line (the tool reads it back without a Lua parser);
- the scanner, the rules and the data writer work on a small made-up addon (no game folder needed).

LayerSwap is not in this repo: it is read from the game folder, or from the path in LSW_DIR.
Without it, the tests that need it are skipped. The known texts are given by their hash keys only.

python3 -m unittest tools.test_lsw_strings
"""
import re
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fxpb_scan as S  # noqa: E402
import glossary  # noqa: E402
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import lsw_words as W  # noqa: E402
import make_lsw_data as M  # noqa: E402
from coverage import compatible, escape_counts  # noqa: E402

HAVE_ADDON = M.have_addon()

# Hash keys (hashtext.key) of texts that must stay English: the channel and addon-message words, the
# invite whisper and its variants, the word lists that read other players' chat, the game's refusal
# lines read back, saved-setting words, the addon's name.
STAY = {"10:21f91a36", "10:248effb2", "10:37e1eac3", "10:68bc06c4", "10:91945fd1", "10:b4f87e01", "11:4a7404d5",
        "11:6166add7", "11:bda8f1b3", "11:e2c93ca1", "14:0a1f0a25", "18:61e92f0c", "20:0c4a1c74", "2:00597897",
        "2:00597902", "2:00597a2c", "37:b91c0f94", "3:0b885e2d", "3:0b885ec4", "3:0b886350", "3:0b887c0c",
        "3:0b888032", "3:0b888bde", "3:0b888be4", "3:0b889596", "3:0b8898a0", "3:0b889a9d", "3:0b889db4",
        "3:0b889dbb", "3:0b889e17", "3:0b88bc72", "3:0b88bc83", "3:0b88bc84", "4:7c97fe63", "4:7c9987e7",
        "4:7c9a2f63", "4:7c9aa212", "4:7c9b1c41", "4:7c9c4733", "4:7c9c6164", "4:7c9d3d45", "4:7c9dca2b",
        "4:7c9e0a4b", "4:7c9e1b4b", "4:7c9e2640", "4:7c9ffbdf", "4:7ca1dc81", "5:0d33a8ba", "5:0e99f684",
        "5:0f3b5d8b", "5:0f88d15a", "5:0f920289", "5:0fd89782", "5:10246bd6", "6:04d5b8f4", "6:0aeb8835",
        "6:14fc2fbf", "6:1c8a8d49", "6:1cc53777", "6:f501ec73", "6:f65ec1cb", "6:fc2b8ece", "7:47edf9eb",
        "7:50bf5a03", "7:54b754c1", "7:6a4b3746", "7:6f803364", "7:8ba14c33", "7:c5c1d963", "7:c73b1d70",
        "7:d5f5447e", "7:da158e07", "8:458519cb", "8:4fdab3ca", "9:0b47092f", "9:621df2fd", "9:f94220eb"}
# Some texts that must be found: three labels and three templates (a chat line, the layer label, a row).
MUST_HAVE = {("exact", "13:04f97572"), ("exact", "88:33640cc9"), ("exact", "77:b02c1635"),
             ("format", "25:2288ecc9"), ("format", "8:ebb2717a"), ("format", "40:f47d3e16")}


@unittest.skipUnless(HAVE_ADDON, f"LayerSwap not found in {M.addon_dir()} (set LSW_DIR)")
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
        self.assertEqual(self.data, text, "data/words.lua is out of date: run python3 tools/make_lsw_data.py")

    def test_each_text_once(self):
        self.assertEqual(len(self.texts), len(set(self.texts)))
        self.assertGreater(len(self.texts), 300)

    def test_known_texts_are_there(self):
        self.assertLessEqual(MUST_HAVE, {(k, H.key(t)) for k, t in self.texts})

    def test_nothing_that_must_stay_english(self):
        events = set(re.findall(r'"([A-Z][A-Z0-9]*_[A-Z0-9_]+)"', self.source))   # events, game globals
        self.assertTrue(events)
        bad = []
        for n, (kind, s) in enumerate(self.texts, 1):
            why = (H.key(s) in STAY and "stays English") or (s in events and "event") \
                or (re.match(r"(?i)inv layer|<LS\b|\[AutoLayer\]", s) and "protocol") \
                or (re.search(r"\\|\.(tga|blp|ttf|ogg)\b|^Interface", s, re.I) and "path") \
                or (re.fullmatch(r"[A-Z][A-Z0-9]*_[A-Z0-9_]+|[a-z]+[A-Z]\w*|#?[0-9A-Fa-f]{6}", s) and "identifier") \
                or (re.match(r"/(ls|layerswap) [\w|/<> ]*$", s) and "slash only") \
                or (re.fullmatch(r"(\|c[0-9a-fA-F]{8}|\|r|%[-.\d]*[sd]|\W)*", s) and "no words")
            if why:
                bad.append(f"#{n} {why}: {H.key(s)}")   # #n: the number in local/layerswap.txt
        self.assertEqual(bad, [])

    def test_templates_have_slots(self):
        no_slot = [H.key(s) for kind, s in self.texts if kind == "format" and not H.is_template(s)]
        self.assertEqual(no_slot, [])

    def test_free_and_blank_slots_are_the_addons(self):
        """Each FREE / BLANK key is one of the addon's templates and names %s slots it has."""
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

    def test_box_texts_not_much_longer_than_english(self):
        """Texts in the panel's fixed boxes fit (docs/LESSONS.md, lesson 5): the status box (2 lines: what
        statusLine returns, its constants, setNotice) and the host line (3 lines: askLine, the hosting
        counts). The Ukrainian may be at most 10% longer than the English, or up to CAP letters. Letters
        are counted with no colour codes or % slots, and a plural mark counts as its longest form."""
        CAP = {"status": 50, "host": 75}
        src = luatok.read(M.addon_dir() / M.MAIN)
        lines = src.split("\n")
        toks = list(luatok.tokens(src))

        def body(pattern):   # the lines of a local function, by its keywords' depth
            start = next(n for n, s in enumerate(lines, 1) if re.search(pattern, s))
            depth = 0
            for t in toks:
                if t[0] != luatok.NAME or t[2] < start:
                    continue
                if t[1] in ("function", "if", "do", "repeat"):
                    depth += 1
                elif t[1] in ("end", "until"):
                    depth -= 1
                    if depth == 0:
                        return set(range(start, t[2] + 1))
            self.fail(f"no end for {pattern}")

        status = body(r"^local function statusLine\(") | {
            n for n, s in enumerate(lines, 1) if re.search(r"\b(HOST_OFF_LINE|PENDING_TEXT|FLASH_LINE)\s*=\s*\"", s)}
        status |= {it.line for it in S.scan(src) if it.sink.startswith("call:setNotice")}
        host = body(r"^local function askLine\(") | {
            n for n, s in enumerate(lines, 1) if re.search(r"hostLine:SetText\(string\.format\(", s)}
        self.assertTrue(len(status) > 100 and len(host) > 20)

        def letters(s):
            s = re.sub(r"\|c[0-9a-fA-F]{8}|\|r|%[-.\d]*[sd]", "", s)
            return len(re.sub(r"\{([^{}|]*)\|([^{}|]*)\|([^{}|]*)\}", lambda m: max(m.groups(), key=len), s))

        g = glossary.Glossary()
        seen = 0
        for area, _, _ in M.AREAS:
            for kind, en, where in self.kept[area]:
                at = {int(w[1:]) for w in where if w[:1] == "L" and w[1:].isdigit()}
                box = "status" if at & status else "host" if at & host else None
                value = box and W.text_of(W.ukrainian([(kind, en)], self.data).get(en), g)
                if not value:
                    continue
                seen += 1
                ua, eng = letters(value), letters(en)
                with self.subTest(key=H.key(en), box=box):
                    self.assertLessEqual(ua, max(eng * 1.10, CAP[box]),
                                         f"{ua} letters, English {eng}: use shorter words, never a smaller font")
        self.assertGreater(seen, 40)


class DataFile(unittest.TestCase):
    def test_one_record_per_line(self):
        text = M.DATA.read_text(encoding="utf-8")
        exact, templates = W.read(text)
        head = "    templates = {\n"
        body = [b for b in re.split(r"^    \},$", text.split(head, 1)[1], maxsplit=1, flags=re.M)[0].split("\n")
                if b.strip()] if head in text else []
        if exact or templates:   # empty until the Ukrainian is written
            self.assertGreater(len(exact), 150)
        self.assertEqual(len(templates), len(body), "a template that read() cannot parse")
        self.assertTrue(all(W.KEY.fullmatch(k) for k in exact))


FIXTURE = r'''
local f = CreateFrame("Frame", nil, UIParent)
f:RegisterEvent("GROUP_ROSTER_UPDATE")
local ICON = "Interface\\AddOns\\Gizmo\\icon.tga"
local function say(m) print(m) end
label:SetText("Shiny Knob")
say("knob turned " .. tostring(n) .. " times.")
say(string.format("%d gears, %.1f%% oiled", n, p))
if db.mode == "quiet" then x = 1 end
if cmd == "debug" then
    say("gear dump " .. tostring(id))
end
'''


class Fixture(unittest.TestCase):
    def test_scanner_and_rules(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / M.MAIN).write_text(FIXTURE, encoding="utf-8")
            kept, skipped = M.collect(d)
        got = {(k, t) for a, rows in kept.items() if a != "joined" for k, t, _ in rows}
        self.assertEqual(got, {("exact", "Shiny Knob"), ("format", "knob turned %s times."),
                               ("format", "%d gears, %.1f%% oiled")})
        reasons = {it.text: why for why, it, _ in skipped}
        self.assertEqual(reasons["gear dump %s"], "debug")
        self.assertEqual(reasons["quiet"], "code")
        self.assertEqual(reasons["GROUP_ROSTER_UPDATE"], "code")

    def test_data_round_trip(self):
        texts = [("exact", "Shiny Knob"), ("format", "%d gears, %.1f%% oiled"), ("format", "knob turned %s times.")]
        uk = {"Shiny Knob": '"Блискуча ручка"', "%d gears, %.1f%% oiled": '"%d шестерень, %.1f%% змащено"',
              "knob turned %s times.": ""}
        data, problems = W.build(texts, uk, glossary.Glossary())
        self.assertEqual(problems, [])
        text = W.write(data, "test")
        self.assertNotIn("Knob", text)
        self.assertNotIn("gears", text)
        self.assertEqual(W.ukrainian(texts, text), {k: v for k, v in uk.items() if v})
