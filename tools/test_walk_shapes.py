"""UADD/Walk.lua (with WalkFrames.lua) and UADD/Shapes.lua: the real files in a small Lua world with made-up words.

Walk: install, a text the font cannot draw, text boxes and skipped frames, a button label and its SetEnabled
(lesson 32), the per-text cache (lesson 12), the hold key, combat (lesson 36), a new frame, a hover that must not
save our font as the label's own (lesson 32, Fresh), a text the addon changed (lesson 23), a lookup that throws
(lesson 19), and off. Shapes: a date slot through UADD.DateUk, numbers, a line with an unknown word, and an error
that leaves the line as it came. Mutants take each fix out and want the test to fail."""
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS / "harness"))
from loader import lua_runtime, read_text  # noqa: E402

LUA = lua_runtime()
CORE = ROOT / "UADD"


def raw(s):
    return s.encode("utf-8").decode("latin-1")


WALK_WORLD = r'''
UADD = {}
local U = UADD
STATS = { faults = 0, lookups = 0 }
function U.Plain(v) return type(v) == "string" and v or nil end
function U.ReportError() end
function U.Fault() STATS.faults = STATS.faults + 1 end
function U.IsCyrFont(p) return p == "CYR" end
function U.SaveFont(fs) return { path = fs.font } end
function U.CyrOnLocked(fs) if fs.nofont then return false end fs:SetFontObject("CYR") return true end
function U.FontBack(fs, was) fs:SetFontObject(was and was.path or "LATIN") end
function U.Locked() return false end
function U.Regions(f) return f.regions or {} end
function U.Children(f) return f.children or {} end
function U.OnNewFrame(fn) STATS.newframe = fn return true end
INCOMBAT = false
function U.AfterCombat(fn) if INCOMBAT then STATS.deferred = fn return true end return false end
function U.OnOriginal(fn) STATS.original = fn end
function U.SafeCall(fn, ...) return pcall(fn, ...) end
function U.Print() end
function hooksecurefunc(t, name, fn)
    local old = t[name]
    t[name] = function(self, ...) local r = old(self, ...) fn(self, ...) return r end
end
function FS(text, font)
    local fs = { text = text, font = font or "LATIN" }
    function fs:GetText() return self.text end
    function fs:SetText(t) self.text = t end
    function fs:SetFormattedText(f, ...) self.text = string.format(f, ...) end
    function fs:GetFont() return self.font end
    function fs:SetFontObject(o) self.font = o end
    function fs:GetObjectType() return "FontString" end
    return fs
end
function Frame(kind, regions, children, name)
    local f = { regions = regions or {}, children = children or {}, kind = kind, name = name }
    function f:GetObjectType() return self.kind end
    function f:GetName() return self.name end
    function f:HookScript(s, fn) self["on" .. s] = fn end
    return f
end
function Button(label, name)
    local b = Frame("Button", {}, {}, name)
    b.label = label
    function b:GetFontString() return self.label end
    function b:SetText(t) self.label.text = t end                         -- draws into its label: no label SetText
    function b:SetEnabled(e) self.label.font = e and "NORMAL" or "DISABLED" end   -- native: no SetFontObject
    return b
end
WORDS = { Hello = "Привіт", Close = "Закрити", Wipe = "Стерти" }
function Lookup(en)
    STATS.lookups = STATS.lookups + 1
    if en == "Boom" then error("boom") end
    return WORDS[en]
end
'''

WALK_SCENARIO = r'''
local out = {}
local function want(c, msg) if not c then out[#out + 1] = msg end end
local U = UADD
ON = true
local a, c, other, boom = FS("Hello"), FS("Hello"), FS("Unknown"), FS("Boom")
local nofont = FS("Close")
nofont.nofont = true
local eb = Frame("EditBox", { FS("Hello") })
local skipme = FS("Hello")
local skipped = Frame("Frame", { skipme }, {}, "PlayerName")
local lbl = FS("Wipe")
local btn = Button(lbl, "RootButton")
local root = Frame("Frame", { a, c, other, nofont, boom }, { eb, skipped, btn }, "RootFrame")
RootFrame = root
local W = U.Walk({ key = "t", On = function() return ON end, roots = { "RootFrame" }, Lookup = Lookup,
    skip = { PlayerName = true }, prefix = "Root", font = true })
W.Install()
want(a.text == "Привіт" and a.font == "CYR", "1 install: " .. a.text .. " " .. a.font)
want(other.text == "Unknown", "1 a word we lack stays")
want(nofont.text == "Close" and nofont.font == "LATIN", "2 a font that fails keeps the English: " .. nofont.text)
want(boom.text == "Boom" and STATS.faults >= 1, "3 a lookup that throws: English, counted")
want(eb.regions[1].text == "Hello", "4 a text box is not walked")
want(skipme.text == "Hello", "4 a skipped frame is not walked")
want(lbl.text == "Стерти" and lbl.font == "CYR", "5 button label: " .. lbl.text .. " " .. lbl.font)
btn:SetEnabled(false)
want(lbl.font == "CYR", "5 SetEnabled keeps our font: " .. lbl.font)
local n = STATS.lookups
for _ = 1, 20 do a:SetText("Hello") end
want(STATS.lookups == n and a.text == "Привіт", "6 one text asks once: " .. (STATS.lookups - n))
U.originalShown = true
STATS.original(true)
want(a.text == "Hello" and a.font == "LATIN", "7 held: English and its font: " .. a.text .. " " .. a.font)
want(lbl.text == "Wipe" and lbl.font == "DISABLED", "7 held: the label's own font: " .. lbl.font)
U.originalShown = false
STATS.original(false)
want(a.text == "Привіт" and a.font == "CYR", "7 released: ours again")
local late = FS("Hello")
root.regions[#root.regions + 1] = late
INCOMBAT = true
W.Later()
want(late.text == "Hello", "8 no walk in combat")
INCOMBAT = false
if STATS.deferred then STATS.deferred() end
want(late.text == "Привіт", "8 the walk after combat")
local child = FS("Hello")
root.children[#root.children + 1] = Frame("Frame", { child }, {}, "RootNew")
STATS.newframe("Frame", "Stranger", nil)
STATS.newframe("Frame", nil, {})
want(child.text == "Hello", "9 another addon's new frame starts no walk")
STATS.newframe("Frame", "RootNew", nil)
want(child.text == "Привіт", "9 a new frame of ours starts a walk")
btn.onOnEnter(btn)
btn.onOnLeave(btn)
btn.onOnEnter(btn)
want(lbl.font == "CYR", "10 hover keeps our font")
a.text = "Hallo"                                       -- the addon drew another language without its SetText
ON = false
W.Sync()
W.Remove()
want(a.text == "Hallo", "11 off leaves a text the addon changed: " .. a.text)
want(c.text == "Hello" and c.font == "LATIN", "12 off: English and its font: " .. c.text .. " " .. c.font)
want(lbl.text == "Wipe" and lbl.font == "DISABLED", "12 off: the label's own font: " .. lbl.text .. " " .. lbl.font)
local fresh = FS("Hello")
root.regions[#root.regions + 1] = fresh
W.Sync()
ON = true
fresh:SetText("Hello")
want(fresh.text == "Hello", "13 off hooks nothing new")
return out
'''

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


def run(world, files, scenario, srcs=None):
    L = LUA.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    L.execute(raw(world))
    load = L.eval("function(src, name) assert(loadstring(src, name))() end")
    for name in files:
        src = (srcs or {}).get(name) or read_text(CORE / name)
        load(src, "@" + name)
    out = L.execute(raw(scenario))
    return [out[i] for i in range(1, len(out) + 1)]


def walk(srcs=None):
    return run(WALK_WORLD, ["WalkFrames.lua", "Walk.lua"], WALK_SCENARIO, srcs)


def shapes(srcs=None):
    return run(SHAPES_WORLD, ["Hash.lua", "CodeText.lua", "Dates.lua", "Shapes.lua"], SHAPES_SCENARIO, srcs)


def caught(fn, name, old, new):
    src = read_text(CORE / name)
    if old not in src:
        return f"{old!r} not in {name}"
    try:
        found = fn({name: src.replace(old, new, 1)})
    except Exception as e:          # a mutant that breaks the file fails too
        found = [str(e)]
    return None if found else "survived"


@unittest.skipIf(LUA is None, "lupa is not installed")
class Walk(unittest.TestCase):
    def test_walk(self):
        self.assertEqual(walk(), [])

    def test_mutants_fail(self):
        mutants = {
            "cache": ("if l and l.en == t then", "if false then"),
            "ours-only": ("if r and t == r.uk then Put(fs, r.en) end", "if r then Put(fs, r.en) end"),
            "fresh": ("if Cyr(fs) then", "if false then"),
            "enabled": ('"SetEnabled", ', ""),
            "combat": ("if U.AfterCombat(Run) then return end", ""),
            "newframe": ("if not F.Starts(spec, name) then return end", ""),
            "guard": ("local ok, uk, keep = pcall(spec.Lookup, t, fs)", "local ok, uk, keep = true, spec.Lookup(t, fs)"),
        }
        for name, (old, new) in mutants.items():
            with self.subTest(name):
                file = "WalkFrames.lua" if name == "enabled" else "Walk.lua"
                self.assertIsNone(caught(walk, file, old, new), name)


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
