"""UADD/Walk.lua (with WalkFrames.lua, ButtonFont.lua, FontObject.lua): the real files in a small Lua world with made-up words.
UADD/Shapes.lua: tools/test_shapes.py (it uses run and caught from here).

Walk: install, a text the font cannot draw, text boxes and skipped frames, a button label whose states the client
switches itself (SetEnabled, the mouse, a state object set later: lessons 32 and 46, ButtonFont.lua loaded for real),
the per-text cache (lesson 12), the hold key, combat (lesson 36), a new frame, no font of ours ever saved as the
text's own (lesson 32, Fresh), a text the addon changed (lesson 23), a lookup that throws
(lesson 19), and off. Mutants take each fix out and want the test to fail."""
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
function U.CyrFontPath() return "CYR" end
U.FontLooks = {}
function U.BoxWatch() end
-- Font.lua as it is for these texts: a button's label goes through ButtonFont.lua (loaded for real), as there.
function U.SaveFont(fs) return { path = fs.font, object = U.FontBase(fs.obj) } end
function U.CyrOnLocked(fs)
    if fs.nofont then return false end
    local btn = U.LabelButton(fs)
    local yes = btn and U.LabelCyr(btn, fs)
    if btn and yes == nil then return false end
    if not yes then fs:SetFontObject("CYR") end
    return true
end
function U.CyrHolds(fs)
    if fs.font ~= "CYR" then return false end
    local btn = U.LabelButton(fs)
    return not btn or U.ButtonCyr(btn, true)
end
function U.FontBack(fs, was)
    local btn = U.LabelButton(fs)
    if btn then
        U.ButtonBack(btn)
        local own = U.FontBase(fs.obj)
        if own ~= fs.obj then U.LabelOn(fs, own) end
        if fs.font ~= "CYR" then return end
    end
    fs:SetFontObject(was and (was.object or was.path) or "LATIN")
end
function U.Locked() return false end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function TICK() local list = timers timers = {} for _, fn in ipairs(list) do fn() end end   -- the next frame
-- Font objects as the client's: each known by its global name, so U.SetFontObject (FontObject.lua) may put it back.
local fonts = 0
function FontObj(path, name)
    fonts = fonts + 1
    local o = { path = path, name = name or ("WorldFont" .. fonts) }
    function o:GetFont() return self.path, 12, "" end
    function o:SetFont(p) self.path = p end
    function o:GetName() return self.name end
    _G[o.name] = o
    return o
end
function CreateFont(name) return FontObj(nil, name) end
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
    function fs:GetFontObject() return self.obj end
    function fs:SetFontObject(o)
        if type(o) == "table" then self.obj, self.font = o, o.path else self.obj, self.font = nil, o end
    end
    function fs:GetParent() return self.parent end
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
-- A button keeps a font object per state; on a state change the client puts that object on the label itself
-- (no SetFontObject of the label runs), under the mouse after the OnEnter script (lesson 46).
local STATES = { "Normal", "Highlight", "Disabled" }
function Button(label, name)
    local b = Frame("Button", {}, {}, name)
    b.label, label.parent = label, b
    b.fonts = { Normal = FontObj("NORMAL"), Highlight = FontObj("HIGHLIGHT"), Disabled = FontObj("DISABLED") }
    b.enabled, b.over = true, false
    function b:Switch()
        local o = self.fonts[not self.enabled and "Disabled" or self.over and "Highlight" or "Normal"]
        self.label.obj, self.label.font = o, o.path
    end
    for _, s in ipairs(STATES) do
        b["Get" .. s .. "FontObject"] = function(self) return self.fonts[s] end
        b["Set" .. s .. "FontObject"] = function(self, o) self.fonts[s] = o self:Switch() end
    end
    function b:GetFontString() return self.label end
    function b:SetText(t) self.label.text = t end                         -- draws into its label: no label SetText
    function b:SetEnabled(e) self.enabled = e and true or false self:Switch() end   -- native: no SetFontObject
    b:Switch()
    return b
end
function Hover(b) b.over = true if b.onOnEnter then b.onOnEnter(b) end b:Switch() end
function Unhover(b) b.over = false if b.onOnLeave then b.onOnLeave(b) end b:Switch() end
function AllCyr(b) for _, s in ipairs(STATES) do if b.fonts[s].path ~= "CYR" then return s end end return nil end
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
want(AllCyr(btn) == nil, "5 every state of the button draws ours: " .. tostring(AllCyr(btn)))
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
TICK()
want(late.text == "Hello", "8 no walk in combat")
INCOMBAT = false
if STATS.deferred then STATS.deferred() end
want(late.text == "Привіт", "8 the walk after combat")
local child = FS("Hello")
root.children[#root.children + 1] = Frame("Frame", { child }, {}, "RootNew")
STATS.newframe("Frame", "Stranger", nil)
STATS.newframe("Frame", nil, {})
TICK()
want(child.text == "Hello", "9 another addon's new frame starts no walk")
STATS.newframe("Frame", "RootNew", nil)
TICK()
want(child.text == "Привіт", "9 a new frame of ours starts a walk")
btn:SetEnabled(true)
Hover(btn)
want(lbl.font == "CYR", "10 under the mouse, before the next frame: " .. lbl.font)
Unhover(btn)
Hover(btn)
TICK()
want(lbl.font == "CYR" and AllCyr(btn) == nil, "10 hover keeps our font: " .. lbl.font)
local own = FontObj("HIGHLIGHT2")
btn:SetHighlightFontObject(own)
want(lbl.font == "CYR" and AllCyr(btn) == nil, "10 a state object the addon sets later gets ours: " .. tostring(AllCyr(btn)))
Unhover(btn)
TICK()
btn:SetEnabled(false)
a.text = "Hallo"                                       -- the addon drew another language without its SetText
ON = false
W.Sync()
W.Remove()
want(a.text == "Hallo", "11 off leaves a text the addon changed: " .. a.text)
want(c.text == "Hello" and c.font == "LATIN", "12 off: English and its font: " .. c.text .. " " .. c.font)
want(lbl.text == "Wipe" and lbl.font == "DISABLED", "12 off: the label's own font: " .. lbl.text .. " " .. lbl.font)
want(btn.fonts.Highlight == own and AllCyr(btn) == "Normal", "12 off: the button's own state objects back")
local fresh = FS("Hello")
root.regions[#root.regions + 1] = fresh
W.Sync()
ON = true
fresh:SetText("Hello")
want(fresh.text == "Hello", "13 off hooks nothing new")
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
    return run(WALK_WORLD, ["FontObject.lua", "ButtonFont.lua", "WalkFrames.lua", "Walk.lua"], WALK_SCENARIO,
               srcs)   # TOC order


def caught(fn, name, old, new):
    """`old` and `new`: one text, or lists of texts each put in its place (one fix held by two lines)."""
    src = read_text(CORE / name)
    pairs = zip(old, new) if isinstance(old, list) else [(old, new)]
    for o, n in pairs:
        if o not in src:
            return f"{o!r} not in {name}"
        src = src.replace(o, n, 1)
    try:
        found = fn({name: src})
    except Exception as e:          # a mutant that breaks the file fails too
        found = [str(e)]
    return None if found else "survived"


@unittest.skipIf(LUA is None, "lupa is not installed")
class Walk(unittest.TestCase):
    def test_walk(self):
        self.assertEqual(walk(), [])

    def test_mutants_fail(self):
        states = 'local STATES = { "Normal", "Highlight", "Disabled" }'
        mutants = {
            "cache": ("Walk.lua", "if l and l.en == t then", "if false then"),
            "ours-only": ("Walk.lua", "if r and t == r.uk then Put(fs, r.en) end", "if r then Put(fs, r.en) end"),
            # never save our font as the text's own (lesson 32): two lines hold it, each alone is enough;
            # a button's own object over our copy (U.FontBase) is flow_button.py's mutant `fontbase`
            "fresh": ("Walk.lua", ["if okH and holds then", "if not (saved[fs] and Cyr(fs)) then"],
                      ["if false then", "if true then"]),
            # every state carries ours (lesson 46): greyed out, under the mouse, an object the addon sets later
            "enabled": ("ButtonFont.lua", states, 'local STATES = { "Normal", "Highlight" }'),
            "hover": ("ButtonFont.lua", states, 'local STATES = { "Normal", "Disabled" }'),
            "setter": ("ButtonFont.lua", '"SetHighlightFontObject", ', ""),
            "combat": ("Walk.lua", "if U.AfterCombat(Run) then return end", ""),
            "newframe": ("Walk.lua", "if not F.Starts(spec, name) then return end", ""),
            "guard": ("Walk.lua", "local ok, uk, keep = pcall(spec.Lookup, t, fs)", "local ok, uk, keep = true, spec.Lookup(t, fs)"),
        }
        for name, (file, old, new) in mutants.items():
            with self.subTest(name):
                self.assertIsNone(caught(walk, file, old, new), name)


if __name__ == "__main__":
    unittest.main()
