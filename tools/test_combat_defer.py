"""Nothing redraws in combat lockdown: the show-original listeners, a popup forgotten, OpenMap's map toggle.

1. UADD/Original.lua runs in a small Lua world. With InCombatLockdown() true, the hold key engaged or let go
   runs no listener. PLAYER_REGEN_ENABLED runs each listener once with the final state; a state that ends
   where it started runs none; a listener that throws does not stop the others; a fight's end whose key check
   throws still runs what waited. With /uadd combat off the key works in a fight, as the player chose.
2. UADD/Popups.lua: a dialog of ours hidden in combat (OnHide -> Forget) gets no SetText or SetHeight then,
   and its English back after combat.
3. UADD_OpenMap/Screen.lua: the World Map shown and hidden in combat, and its tickers, do no Collect; after
   combat one look runs while the map is still shown.
The mutant tests take each gate out (in memory) and want the check to fail.

python3 -m unittest tools.test_combat_defer
"""
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
from loader import lua_runtime  # noqa: E402

LUA = lua_runtime()
ORIGINAL = os.path.join(REPO, "UADD", "Original.lua")
POPUPS = os.path.join(REPO, "UADD", "Popups.lua")
SCREEN = os.path.join(REPO, "UADD_OpenMap", "Screen.lua")
TOC = os.path.join(REPO, "UADD_OpenMap", "UADD_OpenMap.toc")

WORLD = r'''
COMBAT, SHIFT, ERRORS = false, false, 0
function InCombatLockdown() return COMBAT end
function IsShiftKeyDown() return SHIFT end
function GetCurrentKeyBoardFocus() return nil end
function debugstack() return "" end
function debugprofilestop() return 0 end
function GetTime() return 0 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
C_AddOns = { IsAddOnLoaded = function() return false end }
local queue, frames = {}, {}
C_Timer = {
    After = function(_, fn) queue[#queue + 1] = fn end,
    NewTicker = function(_, fn)
        local t = { fn = fn }
        function t.Cancel() t.dead = true end
        TICKERS[#TICKERS + 1] = t
        return t
    end,
}
TICKERS = {}
function RUN()                       -- the timers due now, and any they add
    while #queue > 0 do local fn = table.remove(queue, 1) fn() end
end
function TICK() for _, t in ipairs(TICKERS) do if not t.dead then t.fn() end end end
function CreateFrame()
    local f = { events = {} }
    function f.RegisterEvent(self, e) self.events[e] = true end
    function f.UnregisterEvent(self, e) self.events[e] = nil end
    function f.SetScript(self, _, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end
function FIRE(e) for _, f in ipairs(frames) do if f.events[e] and f.onEvent then f.onEvent(f, e) end end end
UADD_DB = {}
UADD = {}
function UADD.SafeCall(fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then ERRORS = ERRORS + 1 end
    return unpack(r)
end
function UADD.Plain(v) return type(v) == "string" and v or nil end
function UADD.Safe(_, fn) return function(...) return UADD.SafeCall(fn, ...) end end
'''

LISTEN = r'''
TOLD = { a = "", b = "", c = "" }
local function rec(k) return function(show) TOLD[k] = TOLD[k] .. (show and "T" or "F") end end
UADD.OnOriginal(rec("a"), "a")
UADD.OnOriginal(function(show) TOLD.b = TOLD.b .. (show and "T" or "F") error("boom") end, "b")
UADD.OnOriginal(rec("c"), "c")
function KEY(down) SHIFT = down FIRE("MODIFIER_STATE_CHANGED") RUN() end
function RESET() TOLD.a, TOLD.b, TOLD.c = "", "", "" end
'''


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def world(*sources):
    L = LUA.LuaRuntime(unpack_returned_tuples=True)
    L.execute(WORLD)
    for s in sources:
        L.execute(s)
    return L


def told(L):
    t = L.globals().TOLD
    return (t.a, t.b, t.c)


def original_problems(source):
    """[problem] when Original.lua's source runs a listener in combat, or not once with the final state."""
    out = []
    L = world(source, LISTEN)
    g = L.globals()
    L.execute("KEY(true)")                               # held out of combat: English
    if told(L) != ("T", "T", "T"):
        return [f"the key out of combat did not tell every listener once: {told(L)}"]
    if g.ERRORS != 1:
        out.append(f"the throwing listener's error was not caught once: {g.ERRORS}")
    L.execute("RESET() COMBAT = true FIRE('PLAYER_REGEN_DISABLED') KEY(false) KEY(true) KEY(false)")
    if told(L) != ("", "", ""):
        out.append(f"a listener ran in combat (fight starts, key let go and held): {told(L)}")
    L.execute("COMBAT = false FIRE('PLAYER_REGEN_ENABLED')")
    if told(L) != ("F", "F", "F"):
        out.append(f"after combat each listener should run once with the final state F: {told(L)}")

    L.execute("RESET() KEY(true) RESET() COMBAT = true FIRE('PLAYER_REGEN_DISABLED')")
    L.execute("COMBAT = false FIRE('PLAYER_REGEN_ENABLED')")   # key held all fight: ends where it started
    if told(L) != ("", "", ""):
        out.append(f"a fight that ends where it started ran listeners: {told(L)}")
    L.execute("KEY(false) RESET()")

    # the fight's end check throws (SafeCall catches it): what waited still runs once
    L.execute("KEY(true) RESET() COMBAT = true FIRE('PLAYER_REGEN_DISABLED')")
    L.execute("local real = IsShiftKeyDown "
              "IsShiftKeyDown = function() IsShiftKeyDown = real error('odd key state') end "
              "COMBAT = false FIRE('PLAYER_REGEN_ENABLED')")
    if told(L) != ("F", "F", "F"):
        out.append(f"a fight's end whose key check threw did not run what waited: {told(L)}")
    L.execute("SHIFT = false FIRE('MODIFIER_STATE_CHANGED') RUN() RESET()")

    L.execute("UADD_DB.keyInCombat = true COMBAT = true FIRE('PLAYER_REGEN_DISABLED')")
    L.execute("KEY(true) KEY(false) KEY(true)")          # /uadd combat off: the player wants the key in a fight
    if told(L) != ("TFT", "TFT", "TFT"):
        out.append(f"with /uadd combat off the key did not work in a fight: {told(L)}")
    L.execute("RESET() COMBAT = false FIRE('PLAYER_REGEN_ENABLED')")
    if told(L) != ("", "", ""):
        out.append(f"with /uadd combat off the fight's end ran listeners again: {told(L)}")
    L.execute("KEY(false) UADD_DB.keyInCombat = nil")
    return out


POPWORLD = r'''
SETS, HEIGHTS = 0, 0
ACCEPT = "Accept"
UADD.Glossary = { Text = function(id) return ({ ["ui.accept"] = "UK_Accept" })[id] end }
StaticPopupDialogs = { TEST_Q = { button1 = ACCEPT, text = "Sell it?" } }
local function FS()
    local fs = { t = "" }
    function fs.SetText(self, t) SETS = SETS + 1 self.t = t end
    function fs.GetText(self) return self.t end
    function fs.GetHeight(self) return #self.t end
    return fs
end
local d = { h = 100, shown = false, scripts = {} }
function d.GetName() return "StaticPopup1" end
function d.IsShown(self) return self.shown end
function d.GetHeight(self) return self.h end
function d.SetHeight(self, h) HEIGHTS = HEIGHTS + 1 self.h = h end
function d.HookScript(self, k, fn) self.scripts[k] = fn end
d.text = FS()
d.button1 = { fs = FS(), GetFontString = function(self) return self.fs end }
StaticPopup1, STATICPOPUP_NUMDIALOGS = d, 1
function StaticPopup_Show(which)
    local info = StaticPopupDialogs[which]
    d.which, d.shown = which, true
    d.text:SetText(info.text)
    d.button1.fs:SetText(info.button1)
end
function HIDE() d.shown = false if d.scripts.OnHide then d.scripts.OnHide(d) end end
function hooksecurefunc(name, fn)
    local old = _G[name]
    _G[name] = function(...) old(...) fn(...) end
end
'''

POPFLOW = r'''
local P = UADD.Popups
P.Register("T", { names = { TEST_Q = true }, globals = { ACCEPT = "ui.accept" },
    text = function(en) if en == "Sell it?" then return "UK_Sell_it_now?" end end,
    wanted = function() return true end })
P.Sync("T")
StaticPopup_Show("TEST_Q")
SHOWN = StaticPopup1.text.t .. "|" .. StaticPopup1.button1.fs.t
COMBAT, SETS, HEIGHTS = true, 0, 0
HIDE()
INCOMBAT = SETS .. "/" .. HEIGHTS .. "/" .. P.Later()
COMBAT = false
FIRE("PLAYER_REGEN_ENABLED")
AFTER = StaticPopup1.text.t .. "|" .. P.Later() .. "|" .. HEIGHTS
'''


def popup_problems(source):
    L = world(POPWORLD, source, POPFLOW)
    g, out = L.globals(), []
    if g.SHOWN != "UK_Sell_it_now?|UK_Accept":
        return [f"the dialog did not show our words first: {g.SHOWN}"]
    if g.INCOMBAT != "0/0/1":
        out.append(f"hidden in combat: SetText/SetHeight/waiting = {g.INCOMBAT}, want 0/0/1")
    if not str(g.AFTER).startswith("Sell it?|0|"):
        out.append(f"after combat the English is not back on the text: {g.AFTER}")
    return out


MAPWORLD = r'''
COLLECTS, MAPSHOWN, ON = 0, true, true
WorldMapFrame = { scripts = {} }
function WorldMapFrame.IsVisible() return MAPSHOWN end
function WorldMapFrame.GetChildren() COLLECTS = COLLECTS + 1 end
function WorldMapFrame.HookScript(self, k, fn)
    local old = self.scripts[k]
    self.scripts[k] = function(...) if old then old(...) end fn(...) end
end
function MAP(shown) MAPSHOWN = shown local fn = WorldMapFrame.scripts[shown and "OnShow" or "OnHide"] fn() end
local noop = function() end
NS = { On = function() return ON end, Locale = { Sync = noop }, Fonts = { Fix = noop },
    Words = { Sync = noop, Flush = noop, Hook = noop, Apply = noop, HookButton = noop } }
'''

MAPFLOW = r'''
local S = NS.Screen
S.Install() RUN()
COMBAT, COLLECTS = true, 0
MAP(false) MAP(true) MAP(false) MAP(true) TICK() RUN()
INCOMBAT = COLLECTS
COMBAT = false
FIRE("PLAYER_REGEN_ENABLED") RUN()
AFTER = COLLECTS
COMBAT, COLLECTS = true, 0
MAP(false) TICK() RUN()
COMBAT = false
FIRE("PLAYER_REGEN_ENABLED") RUN()
HIDDEN = COLLECTS
'''


def map_problems(source):
    L = world(MAPWORLD)
    load = L.eval("function(src, name, key) if NS[key] == nil then assert(loadstring(src, '@' .. name))('UADD_OpenMap', NS) end end")
    head = read(TOC).split("\nScreen.lua")[0].splitlines()
    for name in (n.strip() for n in head if n.strip() and not n.startswith("#")):   # TOC order (lesson 29)
        src = read(os.path.join(REPO, "UADD_OpenMap", *name.split("/")))
        for key in re.findall(r"^ns\.(\w+) = ", src, re.M):   # a table Screen.lua reads and MAPWORLD lacks: loaded
            if re.search(r"\bns\.%s\b" % key, source):
                load(src, name, key)
    L.eval("function(src) local f = assert(loadstring(src, '@Screen.lua')) f('UADD_OpenMap', NS) end")(source)
    L.execute(MAPFLOW)
    g, out = L.globals(), []
    if g.INCOMBAT != 0:
        out.append(f"the map toggled in combat ran Collect {g.INCOMBAT} times")
    if g.AFTER < 1:
        out.append("after combat, with the map shown, no look ran")
    if g.HIDDEN < 1 or L.eval("NS.Screen.Finding()"):
        out.append("after combat, with the map hidden, the tickers were not put right")
    return out


@unittest.skipIf(LUA is None, "lupa is not installed")
class CombatDefer(unittest.TestCase):
    def test_original_waits_for_combat_end(self):
        self.assertEqual(original_problems(read(ORIGINAL)), [])

    def test_original_mutant_no_gate(self):
        src, gate = read(ORIGINAL), "    if Locked() and U.IgnoreKeyInCombat() then"
        self.assertIn(gate, src)
        self.assertNotEqual(original_problems(src.replace(gate, "    if false then", 1)), [])
        # the opt-out taken out: /uadd combat off would no longer let the key work in a fight
        self.assertNotEqual(original_problems(src.replace(gate, "    if Locked() then", 1)), [])

    def test_original_mutant_no_flush(self):
        src = read(ORIGINAL)
        self.assertIn("        Flush()", src)
        self.assertNotEqual(original_problems(src.replace("        Flush()", "        local _ = Flush", 1)), [])

    def test_popup_forget_in_combat(self):
        self.assertEqual(popup_problems(read(POPUPS)), [])

    def test_popup_mutant_no_gate(self):
        src, gate = read(POPUPS), "    if not Locked() then return Show(d, rec, false) end"
        self.assertIn(gate, src)
        self.assertNotEqual(popup_problems(src.replace(gate, "    if true then return Show(d, rec, false) end", 1)), [])

    def test_openmap_toggle_in_combat(self):
        self.assertEqual(map_problems(read(SCREEN)), [])

    def test_openmap_mutant_no_gate(self):
        src = read(SCREEN)
        gate = "    if ns.On() and S.WaitCombat() then return end"
        self.assertIn(gate, src)
        self.assertNotEqual(map_problems(src.replace(gate, "", 1)), [])


if __name__ == "__main__":
    unittest.main()
