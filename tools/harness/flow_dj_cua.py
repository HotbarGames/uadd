"""UADD_DungeonJournal with ClassicUA (docs/LESSONS4.md lesson 40): the saved name cache never keeps
UALL Forever's words, or its misses, where ClassicUA has a word.

Games, each with the real Dungeon Journal, UALL Forever, UADD and the module:
  1. no ClassicUA (as when it is switched off for a character): the names are collected and saved;
  2. the same saved variables, ClassicUA on: the cache is built again and the quest titles are
     ClassicUA's; the objective lines under a quest ("<item>: 0/6", "0/6 <item>") get ClassicUA's item
     name, a line with an unknown name or a kill line stays whole English;
  3. a fresh start where ClassicUA's hook comes on after UADD's first try to find it: the collection
     waits for it, so no UALL Forever word is saved under ClassicUA's signature; its mutant takes the
     wait out and wants UALL Forever's titles to be kept (so the check bites).
ClassicUA's zone hook is flow_classicua.py's HARNESS STAND-IN (real options, real glossary).
Skipped with a note when ClassicUA is not installed. Called from flow_dj_module.run().
"""
import os

import flow_classicua
import session
from flow_dj import DJSession, EXTRA_LUA, JOURNAL
from loader import Addon, Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = "UADD_DungeonJournal"

LUA = r'''
local H = HARNESS
local Q = {}
H.djcua = Q
local function ns() return H.ns.UADD_DungeonJournal end
function Q.collect()
    local N, t0 = ns().Names, H.time
    H.pump(200000, function() return H.time > t0 + 4 and N.Progress() == nil end, 0.05)
    return N.Progress() == nil
end
function Q.sig() local c = ns().db.cache return c and c.sig or "" end
-- Quest titles ClassicUA has a word for: how many the journal shows as ClassicUA's, how many not.
function Q.titles()
    local N, cua = ns().Names, UADD.UALL.cua
    local hit, stale, sample = 0, 0, nil
    for _, e in ipairs(N.Sources().Quest) do
        local en = type(e.en) == "string" and cua.Fit(e.en)
        local ua = en and cua.Ask(en)
        if type(ua) == "string" then
            if N.Quest(e.id) == cua.Cap(en, ua) then hit = hit + 1
            else stale = stale + 1 sample = sample or (tostring(e.id) .. "=" .. tostring(N.Quest(e.id))) end
        end
    end
    return hit, stale, sample
end
-- An item of the journal with a ClassicUA word: English, ClassicUA's word (capitalised as the route gives it).
function Q.cuaItem()
    local N, cua = ns().Names, UADD.UALL.cua
    for _, e in ipairs(N.Sources().Item) do
        local en = type(e.en) == "string" and cua.Fit(e.en)
        local ua = en and not en:find(":") and cua.Ask(en)
        if type(ua) == "string" then return en, cua.Cap(en, ua) end
    end
end
-- FDJ's objective lines through the journal's own function (wrapped by Whole.lua).
function Q.objectives(...)
    local list = {}
    local args = { ... }
    for i = 1, #args, 2 do list[#list + 1] = { text = args[i], type = args[i + 1], finished = false } end
    local out = ForeverDungeonJournal_NS.LocalizeObjectives(1, list, nil, true) or {}
    local r = {}
    for i, line in ipairs(out) do r[i] = line[1] end
    return r
end
'''


class CuaSession(DJSession):
    """The journal's game with ClassicUA first in the load order (Camelot TOC, as on Forever)."""

    def __init__(self, saved=None, cua=True, hook=True):
        d = session.addons_dir()
        ads = ([Addon("ClassicUA", os.path.join(d, "ClassicUA"), "Camelot")] if cua else []) + \
              [Addon(n, os.path.join(session.REPO, n) if n.startswith("UADD") else os.path.join(d, n),
                     session.FLAVOR) for n in (JOURNAL, "UALLF", "UADD", MODULE)]
        self.client = Client(ads, saved, "enUS")
        self.lua = self.client.lua
        self.lua.execute("HARNESS.__pcall = pcall")
        for name in EXTRA_LUA:
            self.lua.execute(read_text(os.path.join(HERE, name)))
        # dj_load.lua's pcall watch adds two stack levels per pcall, so ClassicUA's frame fell into the part
        # of debugstack that the client leaves out ("..."), and no answer counted. The game's pcall is C.
        self.lua.execute("pcall = HARNESS.__pcall")
        self.H = self.client.H
        self.DJ = self.H.dj
        self.seen_errors = 0
        self.client.start()
        if cua and hook:
            flow_classicua.run_as(self.client, "ClassicUA", flow_classicua.HOOK, False)
        self.pump(60)
        self.lua.execute(LUA)
        self.Q = self.H.djcua


def errors_check(s, check, game):
    # Some of ClassicUA's own files fail to load in the harness (flow_classicua.py): not ours.
    errs = [(w, m) for w, m in s.new_errors() if "AddOns/ClassicUA/scripts/" not in str(m)]
    check(f"{game}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m in errs[:3]))


def run(check, facts):
    if not os.path.isdir(os.path.join(session.addons_dir() or "", "ClassicUA")):
        facts["dj_classicua"] = "skipped: ClassicUA not installed"
        return
    # 1. Without ClassicUA: collected and saved, no ClassicUA part in the signature.
    s = CuaSession(cua=False)
    done, sig = s.Q.collect(), txt(s.Q.sig())
    check("no ClassicUA: names collected, the signature has no ClassicUA part", done and "ClassicUA" not in sig, sig)
    errors_check(s, check, "no ClassicUA")
    saved = s.client.dump_saved()
    del s

    # 2. The same saved names, ClassicUA on: built again, ClassicUA's titles.
    s = CuaSession(saved=saved)
    done, sig = s.Q.collect(), txt(s.Q.sig())
    hit, stale, sample = s.Q.titles()
    facts["dj_classicua_titles"] = {"classicua": int(hit), "other": int(stale), "first_other": txt(sample)}
    check("ClassicUA comes on: the cache is built again under its signature", done and "ClassicUA=" in sig, sig)
    check("ClassicUA comes on: quest titles are ClassicUA's, none kept from the old cache",
          int(hit) > 0 and int(stale) == 0, facts["dj_classicua_titles"])
    en, uk = [txt(x) if x is not None else None for x in (s.Q.cuaItem() or (None, None))]
    if en and uk:
        got = [txt(x) for x in s.Q.objectives(lua_str(f"{en}: 0/6"), lua_str("item"), lua_str(f"0/6 {en}"),
                                              lua_str("item"), lua_str("Zz Nowhere Qq: 0/3"), lua_str("item"),
                                              lua_str(f"{en}: 0/2"), lua_str("monster")).values()]
        want = [f"{uk}: 0/6", f"0/6 {uk}", "Zz Nowhere Qq: 0/3", f"{en}: 0/2"]
        check("objective lines: the item in ClassicUA's word, an unknown name and a kill line whole English",
              got == want, f"got {got} want {want}")
    else:
        check("objective lines: an item with a ClassicUA word in the journal", False, "none found")
    errors_check(s, check, "ClassicUA on")
    del s

    # 3. Fresh, ClassicUA's hook on only after UADD's first try to find it: the collection waits.
    hit, stale, first, settled_early, done, sig = late(check, "late ClassicUA hook")
    facts["dj_classicua_late"] = {"classicua": hit, "other": stale}
    check("ClassicUA's hook comes on late: the collection waits for it, no UALLF title saved in its place",
          first is None and not settled_early and done and hit > 0 and stale == 0 and "ClassicUA=" in sig,
          facts["dj_classicua_late"])
    # Mutant: the wait taken out (Settled always yes): UALL Forever's titles are saved in ClassicUA's place.
    hit, stale, *_ = late(None, "", mutant=True)
    check("mutant settle: without the wait the late game keeps UALL Forever titles (the check bites)",
          stale > 0, {"classicua": hit, "other": stale})


def late(check, game, mutant=False):
    """Game 3: a fresh start, ClassicUA's hook on only after UADD's first try to find it."""
    s = CuaSession(hook=False)
    cua = s.lua.globals().UADD.UALL.cua
    if mutant:
        s.lua.execute("UADD.UALL.cua.Settled = function() return true end")
    s.H.pump(200, lambda: bool(cua.State()[0]), 0.05)                      # ready
    first = cua.Ask(lua_str("Durotar"))                                     # one try, no hook yet
    first = first[0] if isinstance(first, tuple) else first
    settled_early = bool(cua.Settled())
    flow_classicua.run_as(s.client, "ClassicUA", flow_classicua.HOOK, False)
    done = s.Q.collect()
    hit, stale, _ = s.Q.titles()
    sig = txt(s.Q.sig())
    if check:
        errors_check(s, check, game)
    del s, cua
    return int(hit), int(stale), first, settled_early, done, sig
