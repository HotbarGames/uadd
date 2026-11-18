"""UADD_OpenMap on the World Map's hover label, where OpenMap writes its own parts (the stand-in:
tools/harness/openmap/Label.lua): a zone's name with its level range in colour, and its fishing line.

A plain name is the game's and stays as UALL Forever makes it. A name with OpenMap's levels is whole
Ukrainian in UALL Forever's own word for the zone (the one its plain label shows), else a name other
modules saved; a zone with neither stays whole English. "Fishing N" is «Риболовля N» (the glossary's
word), in its colour. The hold key, combat and "/uadd openmap off" give OpenMap's English back.
Called from flow_openmap.in_game.
"""
import re

from loader import lua_str, txt

CYR = re.compile("[Ѐ-ӿ]")
HELD = 0.3
TIRISFAL, RFK, NOWHERE = "Tirisfal Glades", "Razorfen Kraul", "Zorp Blatter"
RED, GREEN = "|cffff8040", "|cff40ff40"
FISH = GREEN + "Fishing 25|r"

LUA = r"""
local M = HARNESS.om
local S = function() return OpenMapStandIn end
function M.hover(name, range, color, fish) S().Hover(name, range, color, fish) end
function M.label() return S().label.Name:GetText(), S().label.Description:GetText() end
function M.labelFont() return (S().label.Name:GetFont()) end
function M.isCyr(path) return UADD.IsCyrFont(path) and true or false end
function M.zone(en)
    local uk = UADD.UALL and UADD.UALL.Zone and UADD.UALL.Zone(en)
    if type(uk) == "string" and uk:find("[\208\209]") then return uk end
    return UADD.CachedName("zones", en)
end
function M.uallf() return (UADD.UALL and UADD.UALL.Zone and UADD.UALL.Zone("Tirisfal Glades")) ~= nil end
function M.glossary(id) return UADD.Glossary.Text(id) end
"""


def _shown(M, name, range_=None, color=RED, fish=FISH):
    M.hover(lua_str(name) if name else None, lua_str(range_) if range_ else None, lua_str(color),
            lua_str(fish) if fish else None)
    a, b = M.label()
    return txt(a), txt(b)


def run(s, M, check):
    s.lua.execute(LUA)
    M.map(True)
    fishing = txt(M.glossary("prof.fishing"))
    fish_uk = f"{GREEN}{fishing} 25|r"
    plain = _shown(M, TIRISFAL, fish=None)[0]
    zone_uk, rfk_uk = txt(M.zone(lua_str(TIRISFAL))), txt(M.zone(lua_str(RFK)))
    if M.uallf():
        check("map label, a plain zone name: left to UALL Forever (its own word, not ours)",
              plain == zone_uk and CYR.search(plain or ""), [plain, zone_uk])
    else:
        check("map label, a plain zone name: left as it is (no UALL Forever here)", plain == TIRISFAL, plain)

    got = _shown(M, TIRISFAL, "1-10")
    want = (f"{zone_uk} {RED}(1-10)|r", fish_uk) if zone_uk else (f"{TIRISFAL} {RED}(1-10)|r", fish_uk)
    check("map label: the zone with OpenMap's levels, and its fishing line, whole Ukrainian",
          got == want and fishing and (not zone_uk or CYR.search(got[0])), {"got": got, "want": want})
    font = txt(M.labelFont())
    check("map label: in a font with Ukrainian letters", M.isCyr(lua_str(font)), font)
    got = _shown(M, RFK, "24", color="|cffffd100", fish="|cffff4040Fishing 1|r")
    want = (f"{rfk_uk} |cffffd100(24)|r", f"|cffff4040{fishing} 1|r")
    check("map label: one level, another colour; a name other modules saved", rfk_uk and got == want,
          {"got": got, "want": want})
    got = _shown(M, NOWHERE, "1-10")
    check("map label: a zone nobody has a word for stays whole English; the fishing line is its own",
          got == (f"{NOWHERE} {RED}(1-10)|r", fish_uk), got)

    _shown(M, RFK, "24-33")
    M.key(True)
    M.wait(HELD)
    now = [txt(x) for x in M.label()]
    held = _shown(M, RFK, "24-33")
    M.key(False)
    M.wait(0.1)
    back = _shown(M, RFK, "24-33")
    check("map label, hold key: OpenMap's English at once and on the next frame; Ukrainian on release",
          now == list(held) == [f"{RFK} {RED}(24-33)|r", FISH] and back == (f"{rfk_uk} {RED}(24-33)|r", fish_uk),
          [now, held, back])
    M.combat(True)
    fought = _shown(M, RFK, "24-33")
    M.combat(False)
    check("map label in combat: left as OpenMap set it", fought == (f"{RFK} {RED}(24-33)|r", FISH), fought)

    s.uadd("openmap off")
    off = [txt(x) for x in M.label()]
    again = _shown(M, RFK, "24-33")
    font = txt(M.labelFont())
    check("map label, /uadd openmap off: English back at once and after, the label's own font back",
          off == list(again) == [f"{RFK} {RED}(24-33)|r", FISH] and not M.isCyr(lua_str(font)),
          [off, again, font])
    s.uadd("openmap on")
    on = _shown(M, RFK, "24-33")
    check("map label, /uadd openmap on: Ukrainian again", on == (f"{rfk_uk} {RED}(24-33)|r", fish_uk), on)
    _shown(M, None)   # the cursor off the map: the label is empty
