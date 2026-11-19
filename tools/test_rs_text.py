"""tools/make_rs_text.py: the slot check, STAY keys, and no English of RareScanner in the built data.
Made-up English only; the last test reads the installed addon and skips when it is not installed."""
import re
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import make_rs_text as M  # noqa: E402
import rs_rules as R  # noqa: E402
import rs_source as S  # noqa: E402

STAY = next(iter(R.STAY))


def write_review(folder, rows, uas):
    """A review file in `folder` with our `uas` {key: UA} for the made-up `rows`."""
    out = []
    for i, (key, en, *_) in enumerate(rows, 1):
        out += M.block(i, key, en, uas.get(key, ""))
    (Path(folder) / "review_01.txt").write_text("\n".join(out), encoding="utf-8")


class SlotCheck(unittest.TestCase):
    def test_dropped_slot(self):
        self.assertTrue(M.check("MAP_TOOLTIP_SEEN", "Wobbly gizmo %s ago", "Хиткий гвинтик тому"))

    def test_moved_colour(self):
        self.assertTrue(M.check("X", "|cffff0000Wobbly|r |T1:0|t gizmo", "|T1:0|t |cffff0000Хиткий|r гвинтик"))
        self.assertTrue(M.check("X", "|cffff0000Wobbly|r gizmo", "|cffff0000Хиткий гвинтик"))

    def test_line_count_and_ends(self):
        self.assertTrue(M.check("X", "Wobbly\ngizmo", "Хиткий гвинтик"))
        self.assertTrue(M.check("X", "Wobbly gizmo ", "Хиткий гвинтик"))

    def test_positional_and_plural(self):
        self.assertTrue(M.check("X", "Wobbly %d gizmo", "Хиткий %1$d {гвинтик|гвинтики}"))

    def test_unsorted_slot(self):
        self.assertTrue(M.check("NO_SUCH_KEY", "Wobbly %s gizmo", "Хиткий %s гвинтик"))

    def test_good(self):
        self.assertEqual(M.check("MAP_TOOLTIP_SEEN", "Wobbly %s gizmo", "Хиткий %s гвинтик"), [])
        self.assertEqual(M.check("X", "|cffff0000Wobbly|r\n gizmo %d", "|cffff0000Хиткий|r\n гвинтик %d"), [])


class Build(unittest.TestCase):
    ROWS = [(STAY, "Wobbly %s gizmo %s", 8, [], ""), ("MAP_TOOLTIP_SEEN", "Wobbly %s ago", 7, [], ""),
            ("X_EMPTY", "Plain gizmo", 1, [], ""), ("X_BAD", "Bent %d gizmo", 1, [], "")]
    UAS = {STAY: "Хиткий %s гвинтик %s", "MAP_TOOLTIP_SEEN": "Хиткий %s тому", "X_BAD": "Зігнутий гвинтик"}

    def test_stay_never_built_and_rerun_keeps_ua(self):
        with tempfile.TemporaryDirectory() as d:
            write_review(d, self.ROWS, self.UAS)
            M.review(self.ROWS, d)          # a rerun keeps the UA lines
            entries, res = M.build(self.ROWS, None, d)
            text = "\n".join(entries)
            self.assertNotIn(STAY, text)
            self.assertIn('T["MAP_TOOLTIP_SEEN"]', text)
            self.assertIn('S["MAP_TOOLTIP_SEEN"] = "v"', text)
            self.assertEqual((res["done"], res["left"]), (1, 1))
            self.assertEqual([k for k, _ in res["bad"]], [STAY, "X_BAD"])
            M.write_data(entries, "0", Path(d) / "data", files=2)
            self.assertEqual(sorted(p.name for p in (Path(d) / "data").iterdir()), ["text01.lua", "text02.lua"])

    def test_toc_lists_every_data_file(self):
        toc = (M.ROOT / "UADD_RareScanner" / "UADD_RareScanner.toc").read_text(encoding="utf-8").split("\n")
        listed = [x.strip() for x in toc if x.strip().startswith("data/")]
        self.assertEqual(listed, [f"data/text{n:02d}.lua" for n in range(1, M.FILES + 1)])
        self.assertLess(toc.index("data/text01.lua"), toc.index("Module.lua"))

    def test_long_value_is_cut(self):
        line = M.lua_entry("T", "K", "ї" * 900)
        self.assertTrue(all(len(x) <= M.MAX_LINE for x in line.split("\n")))


class NoEnglish(unittest.TestCase):
    def test_data_has_no_english_of_the_addon(self):
        addon = M.addon_dir()
        rows, _ = M.source(addon)
        if not rows:
            self.skipTest("RareScanner is not installed")
        english = {en for _, en, *_ in rows if len(en) > 3}
        for p in sorted(M.DATA.glob("text*.lua")):
            for line in p.read_text(encoding="utf-8").split("\n"):
                if line.startswith("T["):
                    value = line.split("] = ", 1)[1]
                    self.assertFalse(any(M.H.lua_str(en) == value for en in english), f"{p.name}: {line[:60]}")
                    self.assertRegex(value, R.CYR.pattern, f"{p.name}: no Ukrainian in {line[:40]}")
                    self.assertFalse(any(line.startswith(f"T[{M.H.lua_str(k)}]") for k in R.STAY), line[:60])


AL_KEY = re.compile(r'\bAL\["([A-Z0-9_]+)"\]')
SAVE_CALL = r"\b\w*DB\.(?:Set|Add)\w*\("                       # a call that saves (may span lines)
DB_SET = re.compile(r'\bdb\w*(?:\.\w+|\[[^\]]+\])+\s*=\s*AL\["([A-Z0-9_]+)"\]')
# a local or a field set in code (not a field in a table constructor: `name = AL["X"],`)
ASSIGN = re.compile(r"(?m)^\s*(?:local\s+([A-Za-z_]\w*)|([A-Za-z_]\w*(?:\.\w+)+))\s*=(?!=)([^\n]*?)\s*$")


def saved_in(text):
    """[(key, line)] of each AL key a file's code writes into saved data (lesson 14): an AL key in a save
    call's args, one set straight into db, or one put in a variable (the same file) a save call is given."""
    out, saves = [], S.calls(text, SAVE_CALL)
    for line, args in saves:
        out += [(k, line) for k in AL_KEY.findall(args)]
    for n, line in enumerate(text.split("\n"), 1):
        out += [(k, n) for k in DB_SET.findall(line)]
    for m in ASSIGN.finditer(text):
        target, rhs = m.group(1) or m.group(2), m.group(3)
        held = re.compile(r"(?<![\w.])%s(?![\w])" % re.escape(target))
        if not rhs.endswith(",") and any(held.search(a) for _, args in saves for a in S.split_args(args)):
            out += [(k, text.count("\n", 0, m.start()) + 1) for k in AL_KEY.findall(rhs)]
    return out


def saved_keys(addon):
    """{key: file:line} of each AL key RareScanner writes into its saved data."""
    out = {}
    for rel, p in S.code_files(addon):
        if p.suffix == ".lua":
            for key, n in saved_in(p.read_text(encoding="utf-8", errors="replace")):
                out.setdefault(key, f"{rel}:{n}")
    return out


class SavedData(unittest.TestCase):
    def test_pattern(self):
        text = "\n".join([
            'RSNpcDB.SetCustomNpcGroupByKey(RSConstants.DEFAULT_GROUP, AL["WOBBLY"])',
            'private.dbglobal.object_names[GetLocale()][id] = AL["GIZMO"]',
            'local name = RSContainerDB.GetContainerName(id) or AL["SHOWN"]',
            'RSGizmoDB.AddWobble(id,', '    AL["SPLIT"])',                  # a call over two lines
            'local function Fix(info)', '    info.label = AL["HELD"]', 'end',
            'local function Keep(id, info)', '    RSGizmoDB.SetLabel(id, info.label)', 'end'])
        self.assertEqual([k for k, _ in saved_in(text)], ["WOBBLY", "SPLIT", "GIZMO", "HELD"])

    def test_saved_text_stays_english(self):
        addon = M.addon_dir()
        if not addon.is_dir():
            self.skipTest("RareScanner is not installed")
        keys = saved_keys(addon)
        self.assertIn("CUSTOM_NPC_GROUP_DEFAULT", keys)  # the scan still finds the cases it was made for
        self.assertIn("CONTAINER", keys)                  # set on vignetteInfo.name, saved later
        bad = {k: w for k, w in keys.items() if k not in R.STAY and k not in R.GAME}
        self.assertEqual(bad, {}, "saved into the player's data: add to STAY (tools/rs_rules.py)")


def formats(addon):
    """{key: [[AL keys in each slot's args]]} of each string.format(AL["KEY"], ...) in RareScanner's code."""
    out = {}
    for _, p in S.code_files(addon):
        if p.suffix == ".lua":
            for _, args in S.calls(p.read_text(encoding="utf-8", errors="replace"), r"\bstring\.format\("):
                parts = S.split_args(args)
                m = re.fullmatch(r'AL\["([A-Z0-9_]+)"\]', parts[0]) if parts else None
                if m:
                    out.setdefault(m.group(1), []).append([AL_KEY.findall(a) for a in parts[1:]])
    return out


class Slots(unittest.TestCase):
    def test_inner_words(self):
        mod = (M.ROOT / "UADD_RareScanner" / "Module.lua").read_text(encoding="utf-8")
        block = re.search(r"\nlocal INNER = \{(.*?)\n\}", mod, re.S).group(1)
        lua = {k: tuple(re.findall(r'"([A-Z0-9_]+)"', v)) for k, v in re.findall(r"(\w+) = \{([^}]*)\}", block)}
        self.assertEqual(lua, R.INNER, "Module.lua INNER and tools/rs_rules.py INNER differ")
        t_keys = {k: s.count("t") for k, s in R.SORTS.items() if "t" in s}
        self.assertEqual({k: len(v) for k, v in R.INNER.items()}, t_keys, "each t slot needs its INNER word")
        addon = M.addon_dir()
        if not addon.is_dir():
            self.skipTest("RareScanner is not installed")
        found = formats(addon)
        for key, words in R.INNER.items():
            seen = [tuple(w for slot in call for w in slot) for call in found.get(key, [])]
            self.assertIn(words, seen, f"{key}: the code fills other words in: {seen}")

    def test_duration_slots_are_u(self):
        addon = M.addon_dir()
        if not addon.is_dir():
            self.skipTest("RareScanner is not installed")
        found = S.duration_keys(addon)
        self.assertIn("MAP_TOOLTIP_RESPAWN_RANGE", found)  # the scan still finds the case it was made for
        for key, slots in found.items():
            sort = R.SORTS.get(key, "")
            self.assertTrue(all(i < len(sort) and sort[i] == "u" for i in slots), f"{key} {slots}: sort it u")
        extra = sorted(k for k, s in R.SORTS.items() if "u" in s and k not in found)
        self.assertEqual(extra, [], "u, but no time span found in the code")


if __name__ == "__main__":
    unittest.main()
