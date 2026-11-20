"""ClassicUA as the first source of game names (UADD/uall_cua.lua, docs/LESSONS2.md lesson 25).

1. Every TOC that lists UALLF in ## OptionalDeps lists ClassicUA too, and UADD.toc loads uall_cua.lua after
   the files whose routes it wraps.
2. uall_cua.lua runs here in a small Lua world (no game, no ClassicUA): a zone text whose SetText hook writes
   Ukrainian back, under a chunk name the test picks. Only an answer from ClassicUA's chunk counts; text with
   "[", "(", "|", a line break or edge spaces is never asked; ClassicUA's options off means UALL Forever
   answers; a name in small letters gets the English's capital.
The mutant tests take a fix out (in memory) and want the check to fail.

python3 -m unittest tools.test_classicua
"""
import glob
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
CUA = os.path.join(REPO, "UADD", "uall_cua.lua")
sys.path.insert(0, os.path.join(HERE, "harness"))
from loader import lua_runtime  # noqa: E402

LUA = lua_runtime()
AFTER = ("uall.lua", "QuestVariants.lua", "Routes.lua", "Collector.lua")

WORLD = r'''
STACK, CALLS, OUT = "", 0, {}
local hooks = {}
function hooksecurefunc(obj, name, fn)
    local old = obj[name]
    obj[name] = function(...) old(...) fn(...) end
end
function debugstack() return STACK end
local function FontString()
    local fs = {}
    function fs.SetText(self, t) self.text = t end
    function fs.IsForbidden() return false end
    return fs
end
local scripts = {}
function CreateFrame()
    local f = { Hide = function() end, RegisterEvent = function() end }
    function f.CreateFontString() return FontString() end
    function f.SetScript(_, _, fn) scripts[#scripts + 1] = fn end
    return f
end
C_Timer = { After = function(_, fn) fn() end }
C_AddOns = { IsAddOnLoaded = function(n) return n == "ClassicUA", true end }
function InCombatLockdown() return false end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
ClassicUA_Options = {}
WORDS = { Durotar = "Дуротар", ["Linen Cloth"] = "лляна тканина" }
ZoneTextString = FontString()
hooksecurefunc(ZoneTextString, "SetText", function(self, t)
    CALLS = CALLS + 1
    local uk = WORDS[t]
    if uk then self:SetText(uk) end
end)
local function uallf(en) return "UALLF:" .. tostring(en) end
UADD = { Meta = function() return "7.1.1" end, UALL = {
    Zone = uallf, Npc = uallf, Item = uallf, Text = uallf, Class = uallf, Spell = uallf,
    UallfAvailable = function() return true end, RouteOff = function() return true end,
    probe = { KINDS = {}, Settings = function() return {} end } } }
function FIRE() for _, fn in ipairs(scripts) do fn() end end
'''


def world(source, stack="Interface/AddOns/ClassicUA/scripts/frame_hooks.lua:870"):
    L = LUA.LuaRuntime(unpack_returned_tuples=True)
    L.execute(WORLD)
    L.globals().STACK = stack
    L.execute(source)
    L.execute("FIRE()")
    return L


def zone(L, en, route="Zone"):
    ua, _ = L.eval("function(r, en) local ua, w = UADD.UALL[r](en) return ua, w end")(route, en)
    return ua


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def deps_problems(tocs):
    """[problem] for {path: text}: UALLF listed without ClassicUA, and uall_cua.lua loaded too early."""
    out = []
    for path, text in tocs.items():
        m = re.search(r"^## OptionalDeps:(.*)$", text, re.M)
        names = [x.strip() for x in m.group(1).split(",")] if m else []
        if "UALLF" in names and "ClassicUA" not in names:
            out.append(f"{path}: OptionalDeps lists UALLF but not ClassicUA")
        if path.endswith("UADD.toc"):
            files = [x.strip() for x in text.splitlines() if x.strip() and not x.startswith("#")]
            if "uall_cua.lua" not in files:
                out.append(f"{path}: uall_cua.lua is not loaded")
            elif any(f in files and files.index(f) > files.index("uall_cua.lua") for f in AFTER):
                out.append(f"{path}: uall_cua.lua must load after {', '.join(AFTER)}")
    return out


def tocs():
    return {p: read(p) for p in glob.glob(os.path.join(REPO, "UADD*", "*.toc"))}


def behaviour_problems(source):
    """[problem] when uall_cua.lua's source, run in the small world, misses one of lesson 25's rules."""
    out = []
    L = world(source)
    if zone(L, "Durotar") != "Дуротар":
        out.append("ClassicUA's answer is not used first")
    if zone(L, "Linen Cloth", "Item") != "Лляна тканина":
        out.append("a name in small letters keeps them though the English has a capital")
    calls = L.globals().CALLS
    for en in ("[Durotar]", "Durotar (1-10)", "Durotar|r", "Duro\ntar", " Durotar", "Durotar "):
        zone(L, en)
    if L.globals().CALLS != calls:
        out.append("text with [, (, |, a line break or edge spaces was asked")
    for key, value in (("disable_all_translation", True), ("translate_zone", False), ("dev_mode", True)):
        L.globals().ClassicUA_Options[key] = value
        if zone(L, "Durotar") != "UALLF:Durotar":
            out.append(f"ClassicUA option {key}={value} is not honoured")
        L.globals().ClassicUA_Options[key] = None
    if L.eval("UADD.UALL.RouteOff('zones')"):
        out.append("a route stays off while ClassicUA answers")
    L = world(source, stack="Interface/AddOns/UALLF/Hooks.lua:12")
    if zone(L, "Durotar") != "UALLF:Durotar":
        out.append("Ukrainian written by another addon's hook was taken as ClassicUA's")
    return out


@unittest.skipIf(LUA is None, "lupa is not installed")
class ClassicUA(unittest.TestCase):
    def test_tocs_list_classicua(self):
        self.assertEqual(deps_problems(tocs()), [])

    def test_behaviour(self):
        self.assertEqual(behaviour_problems(read(CUA)), [])

    def _mutant(self, old, new):
        src = read(CUA)
        self.assertIn(old, src, "uall_cua.lua changed; update this mutant")
        return behaviour_problems(src.replace(old, new, 1))

    def test_mutant_no_source_check_fails(self):
        self.assertTrue(self._mutant("if FromClassicUA() then captured = text end", "captured = text"))

    def test_mutant_no_refusal_fails(self):
        self.assertTrue(self._mutant('en:find("[%[%(|%c]")', "false"))

    def test_mutant_options_ignored_fails(self):
        self.assertTrue(self._mutant("o.translate_zone == false or o.disable_all_translation or o.dev_mode",
                                     "false"))

    def test_mutant_no_capital_fails(self):
        self.assertTrue(self._mutant("ua = ua and Cap(en, ua)", ""))

    def test_mutant_toc_without_classicua_fails(self):
        t = tocs()
        path = next(p for p in t if p.endswith("UADD_Questie.toc"))
        t[path] = t[path].replace(", ClassicUA", "")
        self.assertTrue(deps_problems(t))


if __name__ == "__main__":
    unittest.main()
