"""UADD_WhatsTraining: game names in What's Training?'s windows come from UALL Forever (UADD_WhatsTraining/Names.lua
ns.GameName, and the n slots of ns.Words with spells on), on the stand-in (tools/harness/whatstraining). UALL Forever is
a stand-in too: UADD.UALL.Spell, .Npc, .Zone, .Item and .Text answer from tables set here; every name is made up.

  1. A whole text that is one name it has (a spell row, a trainer): its Ukrainian, in our font (read back).
  2. A name it lacks stays English, whole.
  3. "Not now": English, not asked again within a second, then Ukrainian when the text is set again.
  4. The rank line ("%d ranks of %s", What's Training?'s own English): our words around its spell name.
  5. Hold key and off: English; key up and on: Ukrainian again.
  6. Foreign frames (the CreateFontString hook, review 5b): a parented frame of another addon making many font
     strings is looked at once, then left at once; a forbidden frame is never asked for its regions, even when its
     name starts with "WhatsTraining"; a frame with no parent yet is not marked, and is ours once it gets one.
  7. No Lua errors.
"""
import flow_whatstraining as fw
import hashtext
from flow_whatstraining_texts import rows
from loader import lua_str, txt

RANK_ID = "22:f676e5eb"          # "%d ranks of %s" (data/text01.lua): a value, then a spell name
UK = {"Quix Bolt": "Квікс-стріла", "Zorp the Quixy": "Зорп Квіксовий", "Quix Tide": "Приплив Квікса"}
ROUTE = {"Quix Bolt": "Spell", "Zorp the Quixy": "Npc", "Quix Tide": "Spell"}
STUB = """
local N = { names = { Text = {}, Zone = {}, Npc = {}, Item = {}, Spell = {} }, later = {}, asked = {}, fs = {} }
HARNESS.wtNames = N
for route in pairs(N.names) do
    UADD.UALL[route] = function(en)
        N.asked[en] = (N.asked[en] or 0) + 1
        if N.later[en] then return nil, true end
        return N.names[route][en]
    end
end
local function Make(parent, key, text)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(WhatsTrainingStandIn.PATH, 12, "")
    fs:SetText(text)
    N.fs[key] = fs
    return fs
end
function N.make(key, text) return Make(WhatsTrainingFrame, key, text) end
function N.set(key, text) N.fs[key]:SetText(text) end
function N.shown(key) return N.fs[key]:GetText() or "" end
function N.cyr(key) return UADD.IsCyrFont((N.fs[key]:GetFont())) and true or false end
-- 6: another addon's parented frame making n font strings: how often it was looked at after the first.
function N.foreign(n, wait)
    local f = CreateFrame("Frame", "QuixOtherAddonFrame", UIParent)
    local looks, get = 0, f.GetParent
    f.GetParent = function(self) looks = looks + 1 return get(self) end
    Make(f, "foreign1", "Quix Bolt")
    wait()
    local first = looks
    for i = 1, n do Make(f, "foreign", "Quix Bolt") end
    wait()
    return first, looks - first, N.shown("foreign1")
end
function N.forbidden(wait)
    local asked = 0
    local f = CreateFrame("Frame", "WhatsTrainingForbiddenStandIn", WhatsTrainingFrame)
    f.IsForbidden = function() return true end
    f.GetRegions = function() asked = asked + 1 end
    local g = CreateFrame("Frame", nil, UIParent)
    g.IsForbidden = function() error("forbidden: no look") end
    g.GetRegions = function() asked = asked + 1 end
    for _ = 1, 3 do f:CreateFontString(nil, "OVERLAY") g:CreateFontString(nil, "OVERLAY") end
    wait()
    return asked
end
function N.orphan(wait)
    local f = CreateFrame("Frame")
    Make(f, "orphan", "Quix Bolt")
    wait()
    local before = N.shown("orphan")
    f:SetParent(WhatsTrainingFrame)
    Make(f, "orphan2", "Quix Bolt")
    wait()
    return before, N.shown("orphan2"), N.cyr("orphan2")
end
"""
ROWS = ["spell", "trainer", "missing", "later"]
ENGLISH = {"spell": "Quix Bolt", "trainer": "Zorp the Quixy", "missing": "Quix Gloom", "later": "Quix Tide"}


def _rank():
    """What's Training?'s own English of the rank line, from the installed addon (None when not there)."""
    for en, kind in rows():
        for line in en.split("\n"):
            if hashtext.key(line) == RANK_ID:
                return line
    return None


def run(check, facts):
    c, M = fw._game([fw._stand_in(), fw._addon("UADD"), fw._addon(fw.MODULE)], "enUS")
    c.lua.execute(STUB)
    N = c.H.wtNames
    for en, uk in UK.items():
        N.names[ROUTE[en]][lua_str(en)] = lua_str(uk)
    N.later[lua_str("Quix Tide")] = True

    def wait():
        M.wait(0.1)
    for key in ROWS:
        N.make(key, lua_str(ENGLISH[key]))
    wait()

    def shown():
        return {k: txt(N.shown(k)) for k in ROWS}
    first = shown()
    check("names 1: a spell row and a trainer from UALL Forever, in our font",
          (first["spell"], first["trainer"], N.cyr("spell"), N.cyr("trainer"))
          == (UK["Quix Bolt"], UK["Zorp the Quixy"], True, True), first)
    check("names 2: a name UALL Forever lacks stays English", first["missing"] == "Quix Gloom", first)
    check("names 3: a name 'not now' stays English at first", first["later"] == "Quix Tide", first)
    N.later[lua_str("Quix Tide")] = None
    asked = int(N.asked[lua_str("Quix Tide")])
    N.set("later", lua_str("Quix Tide"))
    check("names 3: not asked again within a second of 'not now' (no garbage)",
          txt(N.shown("later")) == "Quix Tide" and int(N.asked[lua_str("Quix Tide")]) == asked,
          (txt(N.shown("later")), asked, N.asked[lua_str("Quix Tide")]))
    c.H.time = c.H.time + 1.1
    N.set("later", lua_str("Quix Tide"))
    on = shown()
    check("names 3+1: after a second, set again: Ukrainian in our font",
          on["later"] == UK["Quix Tide"] and N.cyr("later"), on)
    _rank_line(check, M, N, wait)
    for step, act, want in (("hold key down", lambda: M.key(True), ENGLISH),
                            ("hold key up", lambda: M.key(False), on),
                            ("/uadd whatstraining off", lambda: M.uadd("whatstraining off"), ENGLISH),
                            ("/uadd whatstraining on", lambda: M.uadd("whatstraining on"), on)):
        act()
        wait()
        now = shown()
        check(f"names 5: {step} (font too)", now == want and N.cyr("spell") == (want is on), (now, N.cyr("spell")))
    first, again, text = N.foreign(200, wait)
    check("names 6: another addon's frame: looked at once, then 200 font strings leave at once, its text as it is",
          int(first) > 0 and int(again) == 0 and txt(text) == "Quix Bolt", (first, again, txt(text)))
    check("names 6: a forbidden frame (also one named WhatsTraining..., one whose look errors): no GetRegions",
          int(N.forbidden(wait)) == 0, "")
    before, after, cyr = N.orphan(wait)
    check("names 6: a frame with no parent yet is not marked: once under What's Training?'s window, ours",
          (txt(before), txt(after), bool(cyr)) == ("Quix Bolt", UK["Quix Bolt"], True), (txt(before), txt(after), cyr))
    fw._errors(c, check, "names")


def _rank_line(check, M, N, wait):
    en = _rank()
    if not en:
        return check("names 4: rank line (skipped: What's Training? not installed)", True, "")
    line = en % (3, "Quix Bolt")
    N.make("rank", lua_str(line))
    N.make("rank2", lua_str(en % (3, "Quix Gloom")))
    wait()
    want = txt(M.fill(lua_str(RANK_ID), lua_str("3"), lua_str(UK["Quix Bolt"])) or "")
    got, miss = txt(N.shown("rank")), txt(N.shown("rank2"))
    check("names 4: the rank line: ours around UALL Forever's spell name, in our font; an unknown spell: English",
          got == want and want != line and N.cyr("rank") and miss == en % (3, "Quix Gloom"), (got, want, miss))
