"""UADD_WhatTheWhisper/Groups.lua and the group thread names (lesson 14): its group chat names a thread with a word of
its locale table and saves that name into its history, so the name stays English. The words drawn nowhere else are
STAY (found in the installed code, listed in Swap.lua); one drawn elsewhere too is ours, and Groups.lua gives the
thread its English back. Swap.lua and Groups.lua in a small Lua world; mutants take each fix out. Made-up English
only; tests that read the installed addon skip when it is missing."""
import re
import sys
import unittest

import test_wtw_text as T

H, R, S = T.H, T.R, T.S
GROUPS = T.MOD / "Groups.lua"
WORLD = r'''
UADD = { errors = {} }
function UADD.Plain(v) return type(v) == "string" and v or nil end
function UADD.SafeCall(fn, ...) if type(fn) ~= "function" then return false end return pcall(fn, ...) end
function UADD.MissedOn() return false end
function UADD.ReportError(e) UADD.errors[#UADD.errors + 1] = e end
function UADD.Fault() end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
EN = { ["Wobbly gizmo"] = "Wobbly gizmo", ["Bent gizmo"] = "Bent gizmo", ["Plain gizmo"] = "Plain gizmo" }
local LABELS = { PARTY = "Wobbly gizmo", GUILD = "Bent gizmo" }
GC = {}
function GC.IsGroupID(id) return type(id) == "string" and id:sub(1, 3) == "CH:" end
function GC.Target(id)
    if not GC.IsGroupID(id) then return nil end
    if id:sub(1, 5) == "CH:C:" then return "CHANNEL", id:sub(6) end
    return id:sub(4)
end
function GC.Label(id)
    if id == "CH:BOOM" then error("its own error", 0) end
    local t, ch = GC.Target(id)
    if t == "CHANNEL" then return ch end
    return LABELS[t] and EN[LABELS[t]] or t
end
ORIG = GC.Label
CONVS = { ["CH:PARTY"] = { isGroup = true, name = "Хиткий гвинтик" }, ["Someone"] = { name = "Хиткий гвинтик" } }
RECS = { ["CH:GUILD"] = { n = "Спільне" }, ["CH:C:Хиткий гвинтик"] = { n = "Хиткий гвинтик" } }
WhatTheWhisper = { LocaleData = { enUS = EN }, ActiveLocale = function() return "enUS" end, GroupChat = GC,
    ConversationManager = { All = function() return CONVS end }, History = { AllRecords = function() return RECS end } }
NS = { AL = { [%r] = "Хиткий гвинтик", [%r] = "Спільне", [%r] = "Спільне" }, SORT = {} }
function NS.On() return true end
''' % ("L." + H.djb2("Wobbly gizmo"), "L." + H.djb2("Bent gizmo"), "L." + H.djb2("Plain gizmo"))
CHECK = r'''
local W, G, out = NS.Swap, NS.Groups, {}
W.SwapIn() G.Install()
if EN["Wobbly gizmo"] == "Wobbly gizmo" then return "ours never went in" end
if GC.Label("CH:PARTY") ~= "Wobbly gizmo" then out[#out + 1] = "a thread named with ours" end
if GC.Label("CH:GUILD") ~= "Bent gizmo" then out[#out + 1] = "a thread named with a shared word of ours" end
if EN["Bent gizmo"] ~= "Спільне" then out[#out + 1] = "ours not back after a shared word" end
if GC.Label("CH:C:Хиткий гвинтик") ~= "Хиткий гвинтик" then out[#out + 1] = "a channel's own name changed" end
if GC.Label("CH:OTHER") ~= "OTHER" then out[#out + 1] = "its own fallback changed" end
local ok, err = pcall(GC.Label, "CH:BOOM")
if ok or err ~= "its own error" then out[#out + 1] = "its own error lost" end
if G.Repair() ~= 2 then out[#out + 1] = "repair count" end
if CONVS["CH:PARTY"].name ~= "Wobbly gizmo" or RECS["CH:GUILD"].n ~= "Bent gizmo" then out[#out + 1] = "not repaired" end
if CONVS["Someone"].name ~= "Хиткий гвинтик" or RECS["CH:C:Хиткий гвинтик"].n ~= "Хиткий гвинтик" then
    out[#out + 1] = "a player's or a channel's name repaired"
end
W.SwapOut()
if GC.Label("CH:PARTY") ~= "Wobbly gizmo" then out[#out + 1] = "English off" end
G.Remove()
if GC.Label ~= ORIG then out[#out + 1] = "its function not back when off" end
if #UADD.errors > 0 then out[#out + 1] = "errors: " .. table.concat(UADD.errors, ", ") end
return table.concat(out, "; ")
'''


def problems(groups=None):
    L = T.LUA.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    raw = lambda s: s.encode("utf-8").decode("latin-1")  # noqa: E731
    L.execute(raw(WORLD))
    L.execute(T.read_text(T.ROOT / "UADD" / "Hash.lua"))
    load = L.eval("function(src, name) assert(loadstring(src, name))('UADD_WhatTheWhisper', NS) end")
    load(T.read_text(T.SWAP), "@Swap.lua")
    load(T.read_text(GROUPS) if groups is None else groups, "@Groups.lua")
    return L.execute(raw(CHECK))


def mutant(old, new):
    src = T.read_text(GROUPS)
    assert old in src, old
    return src.replace(old, new, 1)


class GroupsLua(unittest.TestCase):
    def test_thread_names_english(self):
        self.assertEqual(problems(), "")

    def test_mutant_no_wrap(self):
        self.assertIn("a thread named with ours", problems(mutant("    GC.Label = fn\n", "")))

    def test_mutant_no_shared_word(self):
        self.assertIn("a shared word", problems(mutant("    if k then return k end\n", "    do return k end\n")))

    def test_mutant_channel(self):
        self.assertIn("a channel's own name", problems(mutant("    if Channel(id) then return name end\n", "")))

    def test_mutant_no_repair(self):
        self.assertIn("not repaired", problems(mutant("if en then conv.name, n = en, n + 1 end", "")))


@unittest.skipUnless(T.INSTALLED, "WhatTheWhisper is not installed")
class Installed(unittest.TestCase):
    def test_group_labels_stay_or_ours(self):
        labels = S.group_labels(T.ADDON)
        self.assertGreaterEqual(len(labels), 3)
        stay = {"L." + H.djb2(en) for en, why in S.stay_texts(T.ADDON).items() if why == R.STAY_GROUP}
        al, _ = T.data_entries(T.MOD / "data")
        for en in labels:
            k = "L." + H.djb2(en)
            self.assertTrue(k in stay or (S.elsewhere(T.ADDON, en) and k in al), en)

    def test_swap_lists_every_stay(self):
        src = T.read_text(T.SWAP)
        listed = set(re.findall(r'\["(L\.[0-9a-f]{8})"\] = true', src.split("local BINDINGS")[0]))
        self.assertEqual(listed, {"L." + H.djb2(en) for en in S.stay_texts(T.ADDON)})

    def test_names_list_is_the_same_in_the_module(self):
        lua = T.read_text(T.SWAP)
        block = re.search(r"^local NAMES = \{(.*?)\}", lua, re.S | re.M).group(1)
        self.assertEqual(set(re.findall(r'\["(L\.[0-9a-f]+)"\]', block)), set(R.NAMES))

    def test_groups_in_toc(self):
        toc = (T.MOD / "UADD_WhatTheWhisper.toc").read_text(encoding="utf-8").split()
        self.assertLess(toc.index("Groups.lua"), toc.index("Module.lua"))


if __name__ == "__main__":
    sys.exit(unittest.main())
