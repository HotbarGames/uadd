"""tools/make_wtw_text.py (with tools/key_text.py): the checks, the drafts, the STAY keys, the data files, and no
English of WhatTheWhisper in our files. Swap.lua in a small Lua world: its save to a file is whole English (lesson
14), and ours that two keys share gives no key; mutants take each fix out. Made-up English only; tests that read
the installed addon skip when it is missing."""
import re
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(TOOLS / "harness"))
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import luatok  # noqa: E402
import make_wtw_text as M  # noqa: E402
import wtw_rules as R  # noqa: E402
import wtw_source as S  # noqa: E402
from loader import lua_runtime, read_text  # noqa: E402

ADDON = S.addon_dir()
INSTALLED = (ADDON / S.LOCALE).is_file()
MOD = ROOT / "UADD_WhatTheWhisper"
LUA = lua_runtime()
SWAP = MOD / "Swap.lua"
WORLD = r'''
UADD = {}
function UADD.Plain(v) return type(v) == "string" and v or nil end
function UADD.SafeCall(fn, ...) if type(fn) ~= "function" then return false end return pcall(fn, ...) end
function UADD.MissedOn() return false end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
EN = { ["Wobbly gizmo"] = "Wobbly gizmo", ["Bent gizmo"] = "Bent gizmo", ["Plain gizmo"] = "Plain gizmo" }
SAVED = {}
local function ToFile(fail)
    SAVED[#SAVED + 1] = EN["Wobbly gizmo"]
    if fail then error("its own error", 0) end
    return "done"
end
ORIG = ToFile
WhatTheWhisper = { LocaleData = { enUS = EN }, ActiveLocale = function() return "enUS" end,
    Export = { ToFile = ToFile } }
NS = { AL = { [%r] = "Хиткий гвинтик", [%r] = "Спільне", [%r] = "Спільне" }, SORT = {} }
''' % ("L." + H.djb2("Wobbly gizmo"), "L." + H.djb2("Bent gizmo"), "L." + H.djb2("Plain gizmo"))
SAVE_CHECK = r'''
local W, out = NS.Swap, {}
W.SwapIn() W.Install()
local ours = EN["Wobbly gizmo"]
if ours == "Wobbly gizmo" then return "ours never went in" end
if WhatTheWhisper.Export.ToFile() ~= "done" then out[#out + 1] = "its result lost" end
if SAVED[1] ~= "Wobbly gizmo" then out[#out + 1] = "the saved file holds ours" end
if EN["Wobbly gizmo"] ~= ours then out[#out + 1] = "ours not back after the save" end
local ok, err = pcall(WhatTheWhisper.Export.ToFile, true)
if ok or err ~= "its own error" then out[#out + 1] = "its own error lost" end
if SAVED[2] ~= "Wobbly gizmo" or EN["Wobbly gizmo"] ~= ours then out[#out + 1] = "a failed save left English" end
if W.Saving() then out[#out + 1] = "still saving" end
W.SwapOut() W.Remove()
if WhatTheWhisper.Export.ToFile ~= ORIG then out[#out + 1] = "its function not back when off" end
return table.concat(out, "; ")
'''
DUP_CHECK = r'''
local W, out = NS.Swap, {}
W.Build()
if W.KeyOf("Спільне") ~= nil or W.English("Спільне") ~= nil then out[#out + 1] = "a shared word gave a key" end
if not W.Ours("Спільне") then out[#out + 1] = "a shared word not known as ours" end
if W.KeyOf("Хиткий гвинтик") ~= "Wobbly gizmo" then out[#out + 1] = "a word of one key lost its key" end
if not W.Has("Bent gizmo") or W.Has("Nowhere gizmo") then out[#out + 1] = "Has is wrong" end
return table.concat(out, "; ")
'''


def lua_problems(check, source=None):
    """'' when Swap.lua's source (default: ours) passes `check` in the small world, else what went wrong."""
    L = LUA.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    raw = lambda s: s.encode("utf-8").decode("latin-1")  # noqa: E731
    L.execute(raw(WORLD))
    L.execute(read_text(ROOT / "UADD" / "Hash.lua"))
    src = read_text(SWAP) if source is None else source
    L.eval("function(src) assert(loadstring(src, '@Swap.lua'))('UADD_WhatTheWhisper', NS) end")(src)
    return L.execute(raw(check))


def mutant(old, new):
    src = read_text(SWAP)
    assert old in src, old
    return src.replace(old, new, 1)
OURS = [TOOLS / "make_wtw_text.py", TOOLS / "wtw_rules.py", TOOLS / "wtw_source.py", TOOLS / "test_wtw_text.py"]


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


def write(folder, name, text):
    (Path(folder) / name).write_text(text, encoding="utf-8")


class Checks(unittest.TestCase):
    def test_slots_codes_breaks(self):
        self.assertEqual(R.check("L.x", "Wobbly gizmo", "Хиткий гвинтик"), [])
        self.assertTrue(R.check("L.x", "Wobbly %d gizmo", "Хиткий гвинтик"))
        self.assertTrue(R.check("L.x", "|cffffd200Wobbly|r gizmo", "Хиткий гвинтик"))
        self.assertEqual(R.check("L.x", "|cffffd200Wobbly|r gizmo", "|cffffd200Хиткий|r гвинтик"), [])
        self.assertTrue(R.check("L.x", "Wobbly\ngizmo", "Хиткий гвинтик"))
        self.assertTrue(R.check("L.x", "Wobbly gizmo ", "Хиткий гвинтик"))

    def test_middle_dot_and_dash(self):
        self.assertTrue(R.check("L.x", "Wobbly gizmo", "Хиткий · гвинтик"))
        self.assertEqual(R.check("L.x", "Wobbly gizmo", "Хиткий — гвинтик"), [])
        for key in R.GAME_FONT:
            self.assertTrue(R.check(key, "Wobbly gizmo", "Хиткий — гвинтик"), key)

    def test_unsorted_slot_refused(self):
        self.assertTrue(R.check("L.x", "Wobbly %s gizmo", "Хиткий %s гвинтик"))
        self.assertEqual(R.check("L.x", "Wobbly %d gizmo", "Хиткий %d гвинтик"), [])

    def test_units_and_names_left_out(self):
        units = [k for k, v in R.SORTS.items() if "u" in v or "n" in v]
        self.assertTrue(units)
        for key in units + list(R.NAMES):
            self.assertFalse(R.keep(key, "Wobbly %s gizmo")[0], key)
            self.assertTrue(R.check(key, "Wobbly %s gizmo", "Хиткий %s гвинтик"), key)

    def test_batches_and_weekdays(self):
        self.assertEqual(R.batch_of("L.x", "nothing known"), 3)
        self.assertEqual(sorted(set(R.SECTIONS.values())), [1, 2, 3])
        self.assertEqual(len(R.WEEKDAYS), 7)
        self.assertEqual(len(set(R.WEEKDAYS)), 7)


class Drafts(unittest.TestCase):
    ROWS = [("L." + H.djb2('Wobbly "gizmo"'), 'Wobbly "gizmo"', 1, [], ""),
            ("L." + H.djb2("Two\nlines"), "Two\nlines", 1, [], ""),
            ("L." + H.djb2("Plain gizmo"), "Plain gizmo", 1, [], ""),
            ("X." + H.djb2("Bent gizmo"), "Bent gizmo", 3, [], ""),
            ("X." + H.djb2("Plain gizmo"), "Plain gizmo", 3, [], ""),
            ("Day.2", "Wobblyday", 3, [], "")]
    DRAFT = ("# made-up\nEN: Wobbly \\\"gizmo\\\"\nUA: Хиткий «гвинтик»\n\nEN: Two\\nlines\nUA: Два\\nрядки\n\n"
             "EN: Plain gizmo\nUA: Простий гвинтик\n\nEN: [X] Bent gizmo\nUA: Зігнутий гвинтик\n\n"
             "EN: [Day.2] Wobblyday\nUA: Хиткень\n\nEN: [Day.3] Wobblyday\nUA: Ні\n\nEN: Nowhere gizmo\nUA: Ніде\n")

    def test_keys(self):
        self.assertEqual(M.draft_key("[X] Bent gizmo"), "X." + H.djb2("Bent gizmo"))
        self.assertEqual(M.draft_key("[Day.5] Wobblyday"), "Day.5")
        self.assertEqual(M.draft_key("Bent gizmo"), "L." + H.djb2("Bent gizmo"))

    def test_fills(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "draft_01.txt", self.DRAFT)
            write(d, "notes.txt", "EN: Plain gizmo\nUA: Ні\n")
            fills, unmatched = M.draft_fills(self.ROWS, d)
        k = [r[0] for r in self.ROWS]
        self.assertEqual(fills[k[0]], "Хиткий «гвинтик»")
        self.assertEqual(fills[k[1]], "Два\nрядки")
        self.assertEqual(fills[k[3]], "Зігнутий гвинтик")
        self.assertEqual(fills[k[4]], "Простий гвинтик")      # an X row takes the same English's L draft
        self.assertEqual(fills["Day.2"], "Хиткень")
        self.assertEqual(unmatched, ["[Day.3] Wobblyday", "Nowhere gizmo"])

    def test_no_drafts(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(M.draft_fills(self.ROWS, Path(d) / "missing"), ({}, []))
            self.assertEqual(M.draft_fills(self.ROWS, d), ({}, []))

    def test_round_trip(self):
        """review -> drafts fill only empty UAs -> build -> data files; a rerun keeps every UA."""
        with tempfile.TemporaryDirectory() as d:
            K.review(M.SPEC, self.ROWS, d)
            p = Path(d) / "review_01.txt"
            write(d, "review_01.txt", p.read_text(encoding="utf-8").replace(
                "EN: Plain gizmo\nUA: ", "EN: Plain gizmo\nUA: Мій гвинтик", 1))
            write(d, "draft_02.txt", self.DRAFT[:60])          # a partial draft
            write(d, "draft_01.txt", self.DRAFT)
            sizes, gone, filled, unmatched = M.review(self.ROWS, d)
            self.assertEqual((sizes, gone, filled), ({1: 3, 3: 3}, 0, 5))
            M.review(self.ROWS, d)
            rev = K.read_all(d)
            self.assertEqual(rev[self.ROWS[2][0]][1], "Мій гвинтик")   # the review's own UA wins
            self.assertEqual(rev[self.ROWS[1][0]][1], "Два\nрядки")
            entries, res = K.build(M.SPEC, self.ROWS, None, d)
            self.assertEqual((res["done"], res["left"], res["bad"]), (6, 0, []))
            out = Path(d) / "data"
            K.write_data(M.SPEC, entries, "0", out, files=M.FILES)
            t, _ = data_entries(out)
            self.assertEqual(t["Day.2"], "Хиткень")
            self.assertEqual(len(list(out.glob("text*.lua"))), M.FILES)
            head = (out / "text01.lua").read_text(encoding="utf-8")
            for line in ("local _, ns = ...", "local T = ns.AL or {}; ns.AL = T", "local S = ns.SORT or {}; ns.SORT = S"):
                self.assertIn(line + "\n", head)


@unittest.skipIf(LUA is None, "lupa is not installed")
class SwapLua(unittest.TestCase):
    def test_save_whole_english(self):
        self.assertEqual(lua_problems(SAVE_CHECK), "")

    def test_save_mutant_no_wrap(self):
        self.assertIn("the saved file holds ours", lua_problems(SAVE_CHECK, mutant("    E.ToFile = fn\n", "")))

    def test_save_mutant_error_swallowed(self):
        cut = mutant("        if not ok then error((...), 0) end", "")
        self.assertIn("its own error lost", lua_problems(SAVE_CHECK, cut))

    def test_shared_word_no_key(self):
        self.assertEqual(lua_problems(DUP_CHECK), "")

    def test_shared_word_mutant_last_wins(self):
        cut = mutant("if back[ua] == nil or back[ua] == k then back[ua] = k else back[ua] = false end",
                     "back[ua] = k")
        self.assertIn("a shared word gave a key", lua_problems(DUP_CHECK, cut))


@unittest.skipUnless(INSTALLED, "WhatTheWhisper is not installed")
class Installed(unittest.TestCase):
    rows, why = S.source(ADDON) if INSTALLED else ([], {})
    enus = [en for en, *_ in S.read_enus(ADDON / S.LOCALE)] if INSTALLED else []

    def test_no_english_in_our_files(self):
        ens = {e for e in self.enus if len(e) > 3} | {en for _, en, *_ in self.rows if len(en) > 3}
        ens -= {e for e in ens if "L." + H.djb2(e) in R.NAMES}       # names (the addon's own, format names)
        files = OURS + sorted(MOD.rglob("*.lua")) + sorted(MOD.glob("*.toc"))
        for p in files:
            text = p.read_text(encoding="utf-8")
            for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', text):
                self.assertNotIn(m.group(1), ens, f"{p.name}: its English")
            for line in text.splitlines():
                if line.lstrip().startswith(("--", "#")):
                    for en in ens:
                        if len(en.split()) >= 4:          # a sentence, not a plain two-word term
                            self.assertNotIn(en, line, f"{p.name}: its English in a comment")

    def test_stay_found_and_left_out(self):
        stay = S.stay_texts(ADDON)
        self.assertEqual(sorted(stay.values()).count(R.STAY_STARTER), 4)
        self.assertEqual(sorted(stay.values()).count(R.STAY_FRIEND), 1)
        keys = {k for k, *_ in self.rows}
        for en in stay:
            self.assertIn(en, self.enus)
            self.assertNotIn("L." + H.djb2(en), keys)

    def test_extras(self):
        keys = [k for k, *_ in self.rows]
        self.assertEqual(len([k for k in keys if k.startswith("Day.")]), 7)
        self.assertEqual(len(S.sound_labels(ADDON)), 11)
        for en, _ in S.sound_labels(ADDON):
            self.assertIn("X." + H.djb2(en), keys)
        self.assertEqual(len(S.missing(ADDON, set(self.enus))), 2)

    def test_rule_keys_are_real(self):
        keys = {"L." + H.djb2(e) for e in self.enus}
        for k in list(R.SORTS) + list(R.NOTES) + list(R.NAMES) + list(R.GAME_FONT):
            self.assertIn(k, keys, k)
        secs = {h for _, h in S.sections(ADDON / S.LOCALE)}
        self.assertEqual(secs, set(R.SECTIONS))

    def test_every_slot_sorted_and_batches_fit(self):
        sizes = {}
        for key, en, b, *_ in self.rows:
            self.assertNotIn(None, R.sorts(key, en), key)
            sizes[b] = sizes.get(b, 0) + 1
        self.assertTrue(all(n <= 150 for n in sizes.values()), sizes)

    @unittest.skipUnless((MOD / "data" / "text01.lua").is_file(), "no data built yet")
    def test_data(self):
        """Every built entry is a row and passes the checks, its slots match, no STAY key, all files present."""
        t, s = data_entries(MOD / "data")
        rows = {k: en for k, en, *_ in self.rows}
        stay = {"L." + H.djb2(en) for en in S.stay_texts(ADDON)}
        for key, ua in t.items():
            self.assertRegex(key, r"^(?:L\.[0-9a-f]{8}|X\.[0-9a-f]{8}|Day\.[1-7])$")
            self.assertNotIn(key, stay)
            self.assertIn(key, rows, key)
            self.assertEqual(R.check(key, rows[key], ua), [], key)
            letters = "".join(R.sorts(key, rows[key]))
            self.assertEqual(s.get(key, ""), letters, key)
        self.assertEqual(set(s) - set(t), set())
        for n in range(1, M.FILES + 1):
            self.assertTrue((MOD / "data" / f"text{n:02d}.lua").is_file(), n)


if __name__ == "__main__":
    unittest.main()
