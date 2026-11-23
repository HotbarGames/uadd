"""UADD's safeguards: a failing module falls back to English, never to a broken game (UADD/Safe.lua,
UADD/Guard.lua, UADD/Lines.lua, UADD/AceFont.lua; docs/LESSONS2.md lesson 19). One English game with UADD
alone and two made-up modules (UADD_Probe, UADD_Probe2, run as their own files):

  * safe 1  a module hook that throws: off after 5 errors (its own off path ran, its text English), inert after,
            one error line for one place.
  * safe 2  an Install that fails half way ("/uadd probe2 on"): turned off at once, what it set is undone, its
            unremovable hook stays inert.
  * safe 3  chat (U.ChatLines): wanted() that throws, a number msg, a player's line (no debugstack), and "off"
            after someone wrapped AddMessage after us: every line delivered as it came.
  * safe 4  a 30-line unit tooltip (U.TipLines): no Translate call, no debugstack, the Words cache the same.
  * safe 5  AceGUI Release and SetFocus of another addon's widget: no work (no GetObjectType call).
  * safe 6  a tooltip line pinned to its own Latin font file: the guard gives it its font object back and says
            so once.
  * safe 7  the keyboard held by a text box nobody can see: the guard frees it and says so once.
  * safe 8  as in the client, the line of safe 6 keeps a hand-set file over SetFontObject (wow_widgets.lua): the
            guard's Cyrillic file by hand leaves no boxes; a repair that did not take counts as "tipfail".

python3 tools/harness/flow_safe.py           the checks
python3 tools/harness/flow_safe.py --prove   each step again with its fix taken out: each must FAIL
"""
import collections
import os
import sys

import loader
import session
from loader import Addon, Client

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import hashtext  # noqa: E402

EN, UK = "Hello world", "Привіт, світе"
FROM = 'AddOns[/\\\\]UADD_Probe[/\\\\]'

PROBE = r'''
local U, P = UADD, PROBE
local db = U.DB("probe")
db.enabled = true
P.text = "Ukrainian"
U.RegisterModule("probe", { title = "Probe", Status = function() return "" end, Command = function(a)
    if a == "off" then db.enabled = false P.text = "English" P.ended = (P.ended or 0) + 1 end
end })
P.hook = U.Safe("probe", function(x) P.calls = (P.calls or 0) + 1 error("probe hook broke " .. tostring(x)) end)
function P.send(msg) DEFAULT_CHAT_FRAME:AddMessage(msg) end
'''
PROBE2 = r'''
local U, P = UADD, PROBE
local db = U.DB("probe2")
P.text2 = "English"
local function Install() P.hookA = true P.text2 = "Ukrainian" error("install broke half way") end
U.RegisterModule("probe2", { title = "Probe2", Status = function() return "" end, Command = function(a)
    if a == "on" then db.enabled = true Install()
    elseif a == "off" then db.enabled = false P.hookA = false P.text2 = "English" end
end })
function P.hook2() if db.enabled then P.text2 = "Ukrainian" end end   -- cannot be removed: inert when off
'''
SETUP = r'''
PROBE = { ds = 0 }
local real = debugstack
debugstack = function(...) PROBE.ds = PROBE.ds + 1 return real(...) end
'''


def _cut(cuts):
    """loader.read_text that serves `cuts` ({"Safe.lua": text}) for UADD's own files."""
    plain = loader.read_text

    def read(path):
        p = path.replace("\\", "/")
        for name, text in cuts.items():
            if p.endswith("/UADD/" + name):
                return text.encode("utf-8").decode("latin-1")   # as read_text: bytes as they are
        return plain(path)
    return plain, read


def run(check, facts, cuts=None):
    plain = None
    if cuts:
        plain, loader.read_text = _cut(cuts)
    try:
        _run(check, facts)
    finally:
        if plain:
            loader.read_text = plain


def _run(check, facts):
    c = Client([Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR)], None, "enUS")
    L = c.lua
    L.execute(SETUP)
    c.start()

    def pump(frames, dt=0.05):
        L.execute(f"HARNESS.pump({frames}, function() return false end, {dt})")

    def said(word):
        return sum(word in line for line in c.chat())
    pump(100)                                              # 5 s: the game has settled after login
    c.H.runFile("UADD_Probe", "Module.lua", PROBE)
    c.H.runFile("UADD_Probe2", "Module.lua", PROBE2)
    P = L.globals().PROBE

    # safe 1
    errs0 = said("probe hook broke")
    for i in range(4):
        P.hook(i)
    pump(3)
    early = P.text == "Ukrainian" and not P.ended
    P.hook(4)
    pump(3)
    P.hook(5)
    off = L.eval('UADD.IsTurnedOff and UADD.IsTurnedOff("probe") or false')
    check("safe 1: a module hook that throws: still on after 4 errors", early, P.text)
    check("safe 1: off after 5 errors: its own off path ran once, its text English, the hook inert after",
          off and P.ended == 1 and P.text == "English" and P.calls == 5, f"ended={P.ended} calls={P.calls}")
    check("safe 1: one chat line says the module is off; one error line for one place",
          said("Probe вимкнено") == 1 and said("probe hook broke") - errs0 == 1, c.chat()[-3:])

    # safe 2
    c.slash("probe2 on")
    pump(3)
    P.hook2()
    off2 = L.eval('UADD.IsTurnedOff and UADD.IsTurnedOff("probe2") or false')
    check("safe 2: an Install that fails half way: off at once, what it set undone, its hook inert, English",
          off2 and not P.hookA and P.text2 == "English", f"off={off2} hookA={P.hookA} text={P.text2}")

    # safe 3
    L.execute(f'''
        PROBE.W = UADD.NewWords({{ exact = {{ ["{hashtext.key(EN)}"] = "{UK}" }} }})
        PROBE.want = true
        PROBE.C = UADD.ChatLines({{ words = PROBE.W, from = "{FROM}",
            wanted = function() if PROBE.throw then error("wanted broke") end return PROBE.want end }})
        PROBE.C.Install()'''.encode("utf-8"))
    send = L.eval("function(m) return pcall(PROBE.send, m) end")
    send(EN)
    check("safe 3: chat: our module's line is ours", c.chat()[-1] == UK, c.chat()[-1])
    P.throw = True
    send(EN)
    P.throw = False
    check("safe 3: chat: wanted() throws: the line is delivered as it came", c.chat()[-1] == EN, c.chat()[-1])
    send(42)
    check("safe 3: chat: a number msg is delivered", c.chat()[-1] == "42", c.chat()[-1])
    P.ds = 0
    who = "|Hplayer:Bob|h[Bob]|h: " + EN
    send(who)
    check("safe 3: chat: a player's line: no debugstack, as it came", P.ds == 0 and c.chat()[-1] == who, P.ds)
    L.execute('''local f = DEFAULT_CHAT_FRAME local theirs = f.AddMessage
        f.AddMessage = function(s, m, ...) PROBE.theirs = (PROBE.theirs or 0) + 1 return theirs(s, m, ...) end
        PROBE.C.Restore()''')
    send(EN)
    check("safe 3: chat: off after another addon wrapped after us: their wrapper runs, our words do not",
          c.chat()[-1] == EN and P.theirs == 1, c.chat()[-1])

    # safe 4
    got = L.execute(f'''
        local W = PROBE.W
        PROBE.T = UADD.TipLines({{ tips = {{ "GameTooltip" }}, from = "{FROM}", words = W,
            wanted = function() return true end, missed = "probe" }})
        PROBE.T.Install()
        local tr, n = W.Translate, 0
        W.Translate = function(s) n = n + 1 return tr(s) end
        PROBE.ds = 0
        local size = W.CacheSize()
        GameTooltip:ClearLines()
        for i = 1, 30 do GameTooltip:AddLine("Level " .. i .. " Boar of the woods") end
        W.Translate = tr
        PROBE.tip = {{ n, PROBE.ds, W.CacheSize() - size }}''')
    n, ds, grew = (P.tip[i] for i in (1, 2, 3))
    check("safe 4: a 30-line unit tooltip: no Translate, no debugstack, Words cache the same",
          n == 0 and ds == 0 and grew == 0, f"translate={n} debugstack={ds} cache+={grew}")
    del got

    # safe 5
    L.execute('''
        local gui = rawget(_G, "LibStub") and LibStub("AceGUI-3.0", true)
        if not gui then
            gui = {}
            local libs = { ["AceGUI-3.0"] = gui }
            LibStub = setmetatable({}, { __call = function(_, name) return libs[name] end })
        end
        gui.SetFocus = gui.SetFocus or function() end
        gui.Release = gui.Release or function() end
        UADD.AceFont.Register("ProbeApp", function() return true end)
        local calls = 0
        local fs = { GetObjectType = function() calls = calls + 1 return "FontString" end }
        local w = { label = fs, open = true, userdata = { appName = "OtherApp" } }
        gui:SetFocus(w)
        gui:Release(w)
        PROBE.ace = calls''')
    check("safe 5: AceGUI SetFocus and Release of another addon's widget: no work", P.ace == 0, P.ace)

    # safe 6 and 8, in the client's model: a line keeps a hand-set file over SetFontObject (lesson 44)
    L.execute('GameTooltip:ClearLines() for i = 1, 3 do GameTooltip:AddLine("x") end '
              'GameTooltip:ClearLines()')
    pump(3)
    pin = L.eval('''function(n)
        for i = 1, 3 do GameTooltip:AddLine("x") end
        local fs = _G["GameTooltipTextLeft" .. n]
        local o = fs:GetFontObject()
        fs:SetFont(o:GetFont())
        GameTooltip:ClearLines()
        PROBE.pinned, PROBE.fs, PROBE.obj = rawget(fs, "__pinned"), fs, o
    end''')
    back = L.eval('''function() local fs = PROBE.fs  fs:SetText("\\208\\162\\208\\181\\209\\129\\209\\130")
        return fs:GetFontObject() == PROBE.obj, not (rawget(fs, "__pinned") and not UADD.IsCyrFont((fs:GetFont()))),
            tostring((fs:GetFont())) end''')
    guard = L.eval('function(k) local h = UADD_DB.health h = h and h.guard return h and h[k] or 0 end')
    pin(2)
    planted = P.pinned
    pump(3)
    obj1, cyr1, f1 = back()
    pin(2)
    pump(3)
    obj2, cyr2, f2 = back()
    L.execute("GameTooltip:ClearLines() HARNESS.pump(3, function() return false end, 0.05)")   # no new pin
    check("safe 6: a tooltip line pinned to its own Latin file: its font object back (twice), said once",
          planted is not None and obj1 and obj2 and said("підказка показувала") == 1, f"planted={planted}")
    check("safe 8: ... and a Cyrillic file by hand: no boxes (twice), 2 repairs, none again with no new pin",
          cyr1 and cyr2 and guard("tip") == 2 and guard("tipfail") == 0, f"{f1} {f2} tip={guard('tip')}")
    L.execute('PROBE.own, PROBE.lk = UADD.CyrOnOwn, UADD.CyrOnLocked UADD.CyrOnOwn = function() return false end '
              'UADD.CyrOnLocked = UADD.CyrOnOwn')
    for _ in range(2):
        pin(3)
        pump(3)
    L.execute('UADD.CyrOnOwn, UADD.CyrOnLocked = PROBE.own, PROBE.lk')
    check("safe 8: a repair that did not take: counted as tipfail once, not as fixed, said once",
          guard("tipfail") == 1 and guard("tip") == 2 and said("не вдалося поставити") == 1, guard("tipfail"))

    # safe 7
    L.execute('local e = CreateFrame("EditBox") e:SetAutoFocus(false) e:SetFocus() PROBE.box = e')
    held = L.globals().GetCurrentKeyBoardFocus() is not None
    pump(80)
    free = L.globals().GetCurrentKeyBoardFocus() is None
    check("safe 7: a text box nobody can see held the keyboard: freed, said once",
          held and free and said("клавіатуру тримало") == 1, f"held={held} free={free}")
    facts["chat"] = len(c.chat())


Check = collections.namedtuple("Check", "name ok detail")


def run_checks(cuts=None):
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check(name, bool(ok), str(detail)))
    run(check, facts, cuts)
    return checks, facts


def _replace(name, *pairs):
    """UADD/<name> with each fix cut in memory: pairs are old, new, ...; each old must be there exactly once."""
    with open(os.path.join(session.REPO, "UADD", name), encoding="utf-8") as f:
        text = f.read()
    for o, n in zip(pairs[::2], pairs[1::2]):
        assert text.count(o) == 1, (name, o, text.count(o))
        text = text.replace(o, n)
    return text


def proofs():
    """(step, cuts): each step with its fix taken out."""
    return [("safe 1", {"Safe.lua": _replace("Safe.lua", "local LIMIT = 5 ", "local LIMIT = 1e9 ")}),
            ("safe 2", {"Safe.lua": _replace("Safe.lua", "if not settled or U.installing == key then", "if false then")}),
            ("safe 3", {"Lines.lua": _replace("Lines.lua", "U.SafeCall(h.line, msg)", "true, h.line(msg)",  # unguarded
                                              "pcall(Pick, msg)", "true, Pick(msg)")}),
            ("safe 4", {"Lines.lua": _replace("Lines.lua", "tryL = left and (mine or Maybe(left))", "tryL = left",
                                              "tryR = right and (mine or Maybe(right))", "tryR = right")}),
            ("safe 5", {"AceFont.lua": _replace("AceFont.lua",       # Release walks any widget's strings
                                                "if byWidget[widget] then UADD.SafeCall(Release, widget) end",
                                                "if type(widget) == 'table' then for _, f in ipairs(Strings(widget)) "
                                                "do A.Back(f) end end")}), ("safe 6", {"Guard.lua": ""}),
            ("safe 8", {"Guard.lua": _replace("Guard.lua", "took = U.CyrOnOwn(fs, { size = size, flags = flags, own = true })",
                                              "took = true")}),   # the old guard: its object only
            ("safe 7", {"Guard.lua": ""})]


if __name__ == "__main__":
    if "--prove" in sys.argv:
        bad = 0
        for step, cuts in proofs():
            try:
                cs, _ = run_checks(cuts)
                failed = [x.name for x in cs if x.name.startswith(step) and not x.ok]
            except Exception as e:                      # the cut itself broke the flow: no proof
                failed = []
                print(f"  flow stopped: {e!r}"[:300])
            print(("proof ok  " if failed else "PROOF BAD ") + step + ": " + "; ".join(failed)[:300])
            bad += not failed
        sys.exit(1 if bad else 0)
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
