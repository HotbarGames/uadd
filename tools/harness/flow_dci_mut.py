"""Mutant tests for UADD_DeleteCheapestItem: each takes one fix out of one module file, in memory only (the
H.runFile hook), on a fresh game, and wants its step to fail; without the cut that step must pass.
Every English text is read at run time from the stand-in's feed (DCIStandIn.T, from the installed addon, all rights
reserved). A cut whose old text is not in its file exactly once fails loudly. Run: python3 tools/harness/flow_dci_mut.py
"""
import gc
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flow_dci as F  # noqa: E402
import session  # noqa: E402
from loader import lua_str, read_text, txt  # noqa: E402

MODULE = "UADD_DeleteCheapestItem"

CUT_LUA = r"""
local H, cut = HARNESS, { wasCut = false }
H.dcicut = cut
local runFile = H.runFile
function H.runFile(addon, path, code)
    if addon == "UADD_DeleteCheapestItem" and cut.file and path == cut.file then
        local a, b = code:find(cut.old, 1, true)
        if a then code, cut.wasCut = code:sub(1, a - 1) .. cut.new .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end
"""

# The steps. Each returns ok, detail. No English of the addon here: T(role) reads it at run time.
STEPS_LUA = r"""
local H, D = HARNESS, {}
DciMut = D
local CYR, ZORP = "[\208-\210]", "\208\151\208\190\209\128\208\191"
local function NS() return H.ns.UADD_DeleteCheapestItem end
local function S() return DCIStandIn end
local function T(r) return DCIStandIn.T[r] or "" end
local function cyr(s) return type(s) == "string" and string.find(s, CYR) ~= nil end
local function tr(s) return (NS().Words.Translate(s)) end
local function uadd(m) SlashCmdList.UADD(m) end
local function wait(s) for _ = 1, math.ceil(s / 0.05 - 1e-6) do H.step(0.05) end end
local function text(fs) local ok, t = pcall(fs.GetText, fs) if ok then return t end end
local function show(t) return "[" .. tostring(t) .. "]" end
local function need(...)
    for _, r in ipairs({ ... }) do if T(r) == "" or not cyr(tr(T(r))) then error("no Ukrainian for the role " .. r) end end
end
local calls
local function count()                     -- each Translate call's argument, kept
    local W = NS().Words
    local real = W.Translate
    calls = {}
    W.Translate = function(s, ...) calls[#calls + 1] = s return real(s, ...) end
    return function() W.Translate = real end
end
local function ignored(n)
    local list = {}
    for i = 1, n or 1 do list[i] = { id = 4710 + i } end
    local f = S().OpenIgnored(list) wait(0.3) return f
end
local function link(name) return "|cff1eff00|Hitem:4711::::::::60:::::|h[" .. name .. "]|h|r" end
local function loot(x) return string.format(T("looting"), x) .. "  (" .. T("vendor") .. ": " .. S().Money(1234) .. ")" end
local function items(answer)               -- UALL's item route (lesson 20): each name asked is kept
    local A = UADD.UALL
    local asked, real = {}, A.Item
    A.Item = function(n) asked[#asked + 1] = n return answer(n) end
    return asked, function() A.Item = real end
end

function D.profiles()                      -- lesson 13: a profile named like one of its words stays as typed
    need("profiles", "enter2")
    local en = T("profiles")
    S().SetProfiles({ en }, en) wait(0.1)
    local t, st = text(DCI_ProfileSelect.Text), text(S().status)
    return t == en and cyr(st), "the picker shows " .. show(t) .. ", the status line beside it " .. show(st)
end

function D.global()                        -- "Lesson 1 again": a game global is ours only while it is Latin
    local was, latin = rawget(_G, "DELETE"), true
    if type(was) == "string" and was ~= "" and not cyr(was) then latin = cyr(tr(was)) end
    local odd = "\208\161\209\130\208\181\209\128\209\130\208\184 x"
    DELETE = odd
    local ok, r = pcall(tr, odd)
    DELETE = was
    return latin and ok and r == nil, "Latin global ours: " .. tostring(latin) .. "; a Cyrillic one gives " .. show(r)
end

function D.late()                          -- lesson 2: the ignored items window, made on first open, is ours
    need("ignTitle", "ignReset")
    local f = ignored(1) local a, b = text(f.title), text(f.reset)
    return cyr(a) and cyr(b), "title " .. show(a) .. ", button " .. show(b)
end

function D.maybe()                         -- lesson 12: another owner's tooltip line costs no Translate
    need("tipSettings", "tips")
    local back = count()
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:AddLine(T("tipSettings"))
    local other = #calls
    GameTooltip:SetOwner(DCIFrame, "ANCHOR_NONE")
    GameTooltip:AddLine(T("tips"))
    local own = #calls - other
    back()
    return other == 0 and own >= 1, ("Translate calls: %d for another owner, %d for its window"):format(other, own)
end

function D.guard()                         -- lesson 19: off for errors in its hooks, then on: ours again
    need("remove", "ignTitle")
    wait(4)
    local f = ignored(5)
    local W = NS().Words
    local real, n = W.Translate, 0
    W.Translate = function() n = n + 1 error("dci mutant: a planted error") end
    S().OpenIgnored() wait(0.3)
    W.Translate = real
    local off = not NS().On()
    uadd("dci on")
    wait(0.3) S().OpenIgnored() wait(0.3)
    local bad = 0
    for i = 1, 5 do if not cyr(text(f.rows[i].remove)) then bad = bad + 1 end end
    f.title:SetText(T("ignTitle")) local t = text(f.title)   -- set again: its SetText hook, not a walk, gives ours
    return off and bad == 0 and cyr(t), ("errors %d, off: %s, rows not ours after on: %d, title set again %s")
        :format(n, tostring(off), bad, show(t))
end

function D.readback()                      -- lesson 2: our font read back; none set, the English stays
    need("ignTitle")
    local A = UADD.AceFont
    local set = A.Set
    A.Set = function() end
    local f = ignored(1)
    local t = text(f.title)
    A.Set = set
    uadd("dci off") uadd("dci on") wait(0.3)
    local again = text(f.title)
    return t == T("ignTitle") and cyr(again), "with no font of ours " .. show(t) .. ", with it " .. show(again)
end

function D.secret()                        -- lesson 35: a secret text costs no Translate, and gives nil
    need("ignTitle")
    local f = ignored(1)
    local en = T("ignTitle")
    local back = count()
    H.secret[en] = true
    H.Secret(true)
    local set = pcall(f.title.SetText, f.title, en)
    local seen = 0
    for _, s in ipairs(calls) do if issecretvalue(s) then seen = seen + 1 end end
    local ok, r = pcall(NS().Words.Translate, en)
    local was = issecretvalue(r)
    H.Secret(false) back()
    return set and seen == 0 and ok and r == nil, ("SetText ran: %s, Translate calls with it: %d, Translate gives %s%s")
        :format(tostring(set), seen, was and "a secret" or show(r), ok and "" or " (it threw)")
end

function D.short()                         -- lesson 20: a name cut short ("...") keeps the line English, unasked
    need("vendor", "chatIgnore")
    local asked, back = items(function(n) if string.sub(n, 1, 4) == "Zorp" then return ZORP end end)
    local full, plain = tr(loot(link("Zorp Shard"))), tr(T("chatIgnore") .. "Zorp Shard")
    local a, b = tr(loot(link("Zorp Sha..."))), tr(T("chatIgnore") .. "Zorp Sha...")
    back()
    local dots = 0
    for _, n in ipairs(asked) do if string.sub(n, -3) == "..." then dots = dots + 1 end end
    return cyr(full) and cyr(plain) and a == nil and b == nil and dots == 0,
        ("whole names ours: %s %s; cut in a link %s, cut alone %s; names asked with dots: %d")
            :format(tostring(cyr(full)), tostring(cyr(plain)), show(a), show(b), dots)
end

function D.blocks()                        -- no half lines: two blocks, one with no Ukrainian, stay whole English
    need("popShared")
    local r = tr(T("popShared") .. "\n\nQuix wobbly gizmo.") return r == nil, "gives " .. show(r)
end

function D.later()                         -- a line that asked a route is not kept: ours once the name is known
    local ready = false
    local _, back = items(function(n) if ready and n == "Zorp Late" then return ZORP end end)
    local line = loot(link("Zorp Late"))
    local a = tr(line)
    ready = true
    local b = tr(line) back()
    return a == nil and cyr(b), "before the name " .. show(a) .. ", after " .. show(b)
end

function D.remove()                        -- off: its windows show its English again
    need("ignTitle")
    local f = ignored(1)
    local was = text(f.title) uadd("dci off")
    local t = text(f.title)
    return cyr(was) and t == T("ignTitle"), "on " .. show(was) .. ", off " .. show(t)
end
"""

NEW = {
    "m1 the player's profile name stays as typed": "profiles",
    "m2 a game global ours only while Latin": "global",
    "m3 the ignored items window made late is ours": "late",
    "m4 another owner's tooltip line costs no Translate": "maybe",
    "m5 after the off for errors, on: its hooks give ours again": "guard",
    "m6 no font of ours: the English stays": "readback",
    "m7 a secret text: no Translate, nil": "secret",
    "m8 a name cut short keeps the line English": "short",
    "m9 two blocks, one unknown: whole English": "blocks",
    "m10 a name known later: ours then": "later",
    "m11 off: its English back": "remove",
}
S = list(NEW)

MUTANTS = {
    "skip": ("Screen.lua", "local SKIP = { DCI_ProfileSelect = true, DCI_ProfileName = true }", "local SKIP = {}", S[0]),
    "global": ("Words.lua", "            if find(g, CYR) then return nil end\n", "", S[1]),
    "later": ("Screen.lua", "    end\n    S.Later()\nend", "    end\nend", S[2]),
    "maybe": ("Words.lua", "function W.Maybe() return ns.Screen ~= nil and ns.Screen.OwnsTip() end",
              "function W.Maybe() return true end", S[3]),
    "guard": ("Screen.lua", "local OnSet = ns.Guard(function(self) Apply(self) end)",
              'local OnSet = U.Safe("dci", function(self) Apply(self) end)', S[4]),
    "readback": ("Screen.lua", "        Put(fs, uk)\n        if Font(fs) then", "        Put(fs, uk)\n        if true then", S[5]),
    "plainapply": ("Screen.lua", "    t = U.Plain(t)\n    local r = rec[fs]", "    local r = rec[fs]", S[6]),
    "plainwords": ("Words.lua", "    s = U.Plain(s)\n", "", S[6]),
    "cutlink": ("Slots.lua", '    if not e or sub(x, e - 3, e - 1) == "..." then return nil end',
                "    if not e then return nil end", S[7]),
    "cutname": ("Slots.lua", 'sub(x, -3) == "..." or ', "", S[7]),
    "blocks": ("Words.lua", "        if not uk then return nil end\n        out[#out + 1] = uk",
               "        out[#out + 1] = uk or part", S[8]),
    "asked": ("Words.lua", "    if not asked then", "    if true then", S[9]),
    "remove": ("Module.lua", "    U.SafeCall(ns.Screen.Remove)\n", "", S[10]),
}


def game(cut=None):
    real, box = F.Client, {}

    def client(*a, **k):
        c = real(*a, **k)
        c.lua.execute(CUT_LUA)
        t = box["t"] = c.H.dcicut
        if cut:
            t.file, t.old, t.new = (lua_str(x) for x in cut)
            c.H.boxQuiet = True          # a mutant's boxes are wanted (its step fails), not in the segment's check
        return c
    F.Client = client
    try:
        c, M = F.game()
    finally:
        F.Client = real
    return c, M, box["t"]


def reach(step, cut):
    """(ok, detail, was the cut made) of one step on a fresh game."""
    c, M, t = game(cut)
    try:
        c.lua.execute(STEPS_LUA)
        run = c.lua.eval("function(n) local ok, a, b = pcall(DciMut[n]) if not ok then return false, 'error: ' "
                         ".. tostring(a) end return a == true, b end")
        ok, detail = run(NEW[step])
        ok, detail = bool(ok), txt(detail) if detail is not None else ""
    except Exception as e:  # noqa: BLE001 - a Lua error is a failed step
        ok, detail = False, f"error: {e}"
    was = bool(t.wasCut)
    del c, M, t
    gc.collect()
    return ok, detail, was


def mutants(check, E=None, en=None):
    if not F.module_there() or not F.installed():
        check("mutants: DeleteCheapestItem or the module not there, skipped", True)
        return
    base = {}
    for step in NEW:
        ok, detail, _ = reach(step, None)
        base[step] = ok
        check(f"mutant base: step '{step}' passes without a cut", ok, detail)
    for cut, (path, old, new, step) in MUTANTS.items():
        name = f"mutant {cut} ({path} without that fix, in memory only): step '{step}' fails"
        n = read_text(os.path.join(session.REPO, MODULE, path)).count(old)
        if n != 1:
            check(name, False, f"its old text is in {path} {n} times, not once: the module code moved")
        elif base.get(step) is not True:
            check(name + " - base fails now (H2), not counted", True)
        else:
            ok, detail, was = reach(step, (path, old, new))
            check(name, was and not ok, "cut not found" if not was else ("it passed" if ok else "killed: " + detail))


def run_checks():
    checks = []

    def check(name, ok, detail=""):
        checks.append(F.Check("dci: " + name, bool(ok), str(detail)))
    mutants(check)
    return checks, {}


if __name__ == "__main__":       # alone: python3 tools/harness/flow_dci_mut.py
    cs, _ = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
