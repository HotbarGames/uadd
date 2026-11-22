"""Dungeon Journal objective lines (UADD_DungeonJournal/Whole.lua, docs/LESSONS4.md lesson 40).

Whole.lua runs here in a small Lua world: a stand-in FDJ.LocalizeObjectives that gives back each line's text, and a
stand-in UADD.UALL.Item that answers ClassicUA's word first and UALL Forever's on a miss (the real route order is
tools/test_classicua.py's; the real journal with real ClassicUA is tools/harness/flow_dj_cua.py's game 2). Made-up
names only. Each line must come out whole Ukrainian with the game's numbers kept, or exactly as the game gave it.
The mutant tests take a fix out (in memory) and want the check to fail.

python3 -m unittest tools.test_dj_objectives
"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
WHOLE = os.path.join(REPO, "UADD_DungeonJournal", "Whole.lua")
sys.path.insert(0, os.path.join(HERE, "harness"))
from loader import lua_runtime  # noqa: E402

LUA = lua_runtime()

WORLD = r'''
CUA = { ["Zorp Satchel"] = "Сумка Зорпа", ["Wobble Root"] = "Корінь Хитуна" }
UALLF = { ["Quix Gizmo"] = "Ґаджет Квікса", ["Zorp Satchel"] = "Торба Зорпа" }
THROW, ACTIVE = false, true
UADD = { UALL = { Item = function(en)
    if THROW then error("lookup broke") end
    return CUA[en] or UALLF[en]
end } }
function UADD.Safe(_, fn)
    return function(...)
        local r = { pcall(fn, ...) }
        if r[1] then return unpack(r, 2) end
    end
end
NS = { Lang = { Active = function() return ACTIVE end, LOCALE = "ukUA" } }
local function FdjObjectives(questID, objectives)
    local out = {}
    for i, o in ipairs(objectives) do out[i] = { o.text, o.finished } end
    return out
end
ForeverDungeonJournal_NS = { LocalizeObjectives = FdjObjectives, LocalizeFreeText = function(v) return v end }
FDJ_ORIG = FdjObjectives
function RUN(...)
    local list, a = {}, { ... }
    for i = 1, #a, 2 do list[#list + 1] = { text = a[i], type = a[i + 1], finished = false } end
    local out = ForeverDungeonJournal_NS.LocalizeObjectives(7, list)
    local r = {}
    for i, line in ipairs(out) do r[i] = line[1] end
    local same = true
    for i, o in ipairs(list) do if o.text ~= a[2 * i - 1] then same = false end end
    return r, same
end
'''


def world(source):
    L = LUA.LuaRuntime(unpack_returned_tuples=True)
    L.execute(WORLD)
    L.eval("function(src) local f = assert(loadstring(src, '@Whole.lua')) f('UADD_DungeonJournal', NS) end")(source)
    L.execute("NS.Whole.Install(ForeverDungeonJournal_NS)")
    return L


def run(L, *pairs):
    try:
        out, same = L.globals().RUN(*pairs)
    except Exception as e:  # an error that reached FDJ's caller
        return [f"error: {str(e)[:80]}"], False
    return [out[i] for i in range(1, len(out) + 1)], same


def problems(source):
    """[problem] for a Whole.lua source: cases (a)-(g) of the objective-line wrap."""
    L, out = world(source), []

    def want(name, got, expect):
        if got != expect:
            out.append(f"{name}: got {got} want {expect}")

    got, same = run(L, "0/6 Zorp Satchel", "item")
    want("a ClassicUA word, numbers first", got, ["0/6 Сумка Зорпа"])
    if not same:
        out.append("a: the game's own list was changed")
    want("b only UALL Forever has the word", run(L, "2/5 Quix Gizmo", "item")[0], ["2/5 Ґаджет Квікса"])
    want("c unknown item", run(L, "0/3 Zz Nowhere Qq", "item")[0], ["0/3 Zz Nowhere Qq"])
    want("d name first", run(L, "Wobble Root: 1/4", "object", "Quix Gizmo: 0/2", "item")[0],
         ["Корінь Хитуна: 1/4", "Ґаджет Квікса: 0/2"])
    want("e kill line", run(L, "Zorp Satchel: 0/2", "monster", "0/6 Zorp Satchel", "item")[0],
         ["Zorp Satchel: 0/2", "0/6 Сумка Зорпа"])
    L.execute("THROW = true")
    want("f the lookup throws", run(L, "0/6 Zorp Satchel", "item", "Wobble Root: 1/4", "item")[0],
         ["0/6 Zorp Satchel", "Wobble Root: 1/4"])
    L.execute("THROW = false ACTIVE = false")
    want("our language not shown", run(L, "0/6 Zorp Satchel", "item")[0], ["0/6 Zorp Satchel"])
    L.execute("ACTIVE = true NS.Whole.Uninstall(ForeverDungeonJournal_NS)")
    if not L.eval("ForeverDungeonJournal_NS.LocalizeObjectives == FDJ_ORIG"):
        out.append("g off: FDJ's own LocalizeObjectives is not back")
    want("g off: lines as the game gave them", run(L, "0/6 Zorp Satchel", "item")[0], ["0/6 Zorp Satchel"])
    return out


@unittest.skipIf(LUA is None, "lupa is not installed")
class Objectives(unittest.TestCase):
    def source(self):
        with open(WHOLE, encoding="utf-8") as f:
            return f.read()

    def test_whole_lines(self):
        self.assertEqual(problems(self.source()), [])

    def mutant(self, old, new):
        src = self.source()
        self.assertIn(old, src, "the mutant's text is gone from Whole.lua: update the test")
        self.assertNotEqual(problems(src.replace(old, new, 1)), [])

    def test_mutant_no_wrap(self):       # the wrap not put in: lines stay English
        self.mutant("origObjectives, fdj.LocalizeObjectives = fdj.LocalizeObjectives, LocalizeObjectives",
                    "origObjectives = fdj.LocalizeObjectives")

    def test_mutant_kill_lines(self):    # kill lines translated too
        self.mutant('o.type == "monster"', 'o.type == "nothing"')

    def test_mutant_not_safe(self):      # the lookup's error reaches FDJ
        self.mutant('local Prepare = UADD.Safe("dj", function(objectives)',
                    'local Prepare = (function(_, f) return f end)("dj", function(objectives)')

    def test_mutant_no_restore(self):    # off leaves our wrap in
        self.mutant("then fdj.LocalizeObjectives = origObjectives end", "then end")

    def test_mutant_latin_kept(self):    # a word with Latin letters is taken as whole Ukrainian
        src = self.source().replace('uk:find("[%a|{}]") or ', "", 1)
        L = world(src)
        L.execute('CUA["Zorp Satchel"] = "Сумка Zorp"')
        self.assertNotEqual(run(L, "0/6 Zorp Satchel", "item")[0], ["0/6 Zorp Satchel"])
        L = world(self.source())
        L.execute('CUA["Zorp Satchel"] = "Сумка Zorp"')
        self.assertEqual(run(L, "0/6 Zorp Satchel", "item")[0], ["0/6 Zorp Satchel"])


if __name__ == "__main__":
    unittest.main()
