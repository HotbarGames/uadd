"""UADD/Shapes.lua: the real file (with Hash.lua, CodeText.lua, Dates.lua) in a small Lua world with made-up words.

A date slot through UADD.DateUk, numbers, a line with an unknown word, and an error that leaves the line as it came.
Mutants take each fix out and want the test to fail. Split from tools/test_walk_shapes.py (its run and caught)."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_walk_shapes import LUA, caught, run  # noqa: E402

SHAPES_WORLD = r'''
UADD = {}
local U = UADD
STATS = { faults = 0 }
function U.Plain(v) return type(v) == "string" and v or nil end
function U.ReportError() end
function U.Fault() STATS.faults = STATS.faults + 1 end
U.UALL = {}
'''

SHAPES_SCENARIO = r'''
local U = UADD
local T, SORT = {}, {}
local function add(en, uk, sorts) local k = "Code." .. U.Hash(en) T[k], SORT[k] = uk, sorts end
add("Seen %s", "Бачено %s", "v")
add("Level %d of %d", "Рівень %d з %d", "vv")
add("Note %s", "Нотатка %s", "t")
local P = U.Shapes(T, SORT, { key = "s", Line = function(x) if x == "boom" then error("boom") end return nil end })
local out = {}
local function want(c, msg) if not c then out[#out + 1] = msg end end
local got = P.Shapes("Seen 12 Nov 2026")
want(got == "Бачено 12 лист. 2026", "1 a date slot: " .. tostring(got))
got = P.Shapes("Seen Sunday, 12 November")
want(got == "Бачено Неділя, 12 листопада", "1 a weekday date: " .. tostring(got))
want(P.Shapes("Seen 12 Nov at noon") == nil, "2 an unknown word keeps the line English")
want(P.Shapes("Seen bob") == nil, "2 a word in a value slot keeps the line English")
got = P.Shapes("Level 5 of 9")
want(got == "Рівень 5 з 9", "3 numbers: " .. tostring(got))
want(P.Shapes("Nothing of ours here") == nil, "4 a line with no template")
local f = STATS.faults
want(P.Shapes("Note boom") == nil and STATS.faults == f + 1, "5 an error: nil, counted")
return out
'''


def shapes(srcs=None):
    return run(SHAPES_WORLD, ["Hash.lua", "CodeText.lua", "Dates.lua", "Shapes.lua"], SHAPES_SCENARIO, srcs)


@unittest.skipIf(LUA is None, "lupa is not installed")
class Shapes(unittest.TestCase):
    def test_shapes(self):
        self.assertEqual(shapes(), [])

    def test_mutants_fail(self):
        mutants = {
            "date": ("U.DateUk and U.DateUk(x) or nil", "nil"),
            "pcall": ("local ok, uk = pcall(Tries, s, d)", "local ok, uk = true, Tries(s, d)"),
        }
        for name, (old, new) in mutants.items():
            with self.subTest(name):
                self.assertIsNone(caught(shapes, "Shapes.lua", old, new), name)


if __name__ == "__main__":
    unittest.main()
