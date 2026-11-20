"""UADD_Mastercraft: lines Mastercraft builds in its code, on the stand-in, in a game of their own
(called from flow_mastercraft.run). The English comes from the installed addon by hash key (the flow's
rows()); game names are made up and given UALL Forever's Ukrainian here, so none of Mastercraft's names
are in this file.

  * Alts: an alt's zone line (zone, dash, status) takes the zone's name from UALL Forever (a game name,
    never kept as a free name: that made a half line, the English zone before our status,
    tools/mc_rules.py); a zone it lacks keeps the whole line English.
  * The level line with race and class from UALL Forever; one it lacks stays English. A name UALL Forever
    cannot give yet shows English first, our Ukrainian after the screen tries again (2 s).
  * The Crafters hub's raw strings (Raw.lua): the line under the name, the note (the player's own words
    kept), the tile's empty text, a count and a watched recipe's line are ours; a favourite's name stays
    as it is even when it reads like one of Mastercraft's texts (lesson 13); off gives the English back.
  * Item tooltip lines from Mastercraft's code: the price per piece (two forms), a chance with its
    percent, the crafter with the profession, the disenchant row with an item UALL Forever has; an
    unknown item stays English.
  * Guards: an error inside our write leaves the text English and off still works; a forbidden frame is
    never asked for its regions; another addon's frame is looked at twice at most; the login scan is
    spread over game frames.
"""
import os

import hashtext
from loader import Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
# Made-up game names with "UALL Forever's" Ukrainian, and ones it lacks.
ZONE, ZONE_UK, ZONE_NONE, ZONE_WAIT = "Quixbury Hollow", "Квіксова Балка", "Blorp Fen", "Waity Vale"
RACE, RACE_UK, CLASS, CLASS_UK, CLASS_NONE = "Quixling", "Квіксель", "Wobbler", "Хитун", "Blorpmage"
ITEM, ITEM_UK, ITEM_NONE = "Wobbly Vest", "Хиткий жилет", "Blorpy Vest"
PLAYER, NOTE = "|cffc79c6eHoba|r", '"Wobbly bags, ask me"'
GREY, WHITE = "|cff8c8c8c", "|cffffffff"
KEYS = {"zone": "17:cf89bec3", "level": "11:c97b8fde", "level3": "14:ea7f7876", "avail": "12:366f0baf",
        "zonecount": "15:e0978530", "notehead": "15:dc527bfc", "nonote": "55:a9bc0646",
        "empty": "24:83c27475", "prof": "9:468c47ae", "likely": "6:c0cf8a0f", "canmake": "27:885d172b",
        "each": "7:32a7c1ce", "ea": "5:0adc2fe3", "by": "19:d68addfb", "de": "24:a3fbd071"}


def _game(F):
    c = Client([F._stand_in(), F._addon("UADD"), F._addon(F.MODULE)], None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_mastercraft.lua")))
    c.lua.execute(read_text(os.path.join(HERE, "flow_mc_code.lua")))
    c.start()
    c.H.pump(60)
    return c, c.H.mc, c.H.mcCode


def run(check, F, src):
    en = {hashtext.key(e): e for e, _ in src}
    miss = [k for k, key in KEYS.items() if key not in en]
    check("code: each text read from the installed Mastercraft by its key", not miss, miss)
    if miss:
        return
    E = {k: en[key] for k, key in KEYS.items()}
    c, M, C = _game(F)
    for a, b in ((ZONE, ZONE_UK), (RACE, RACE_UK), (CLASS, CLASS_UK), (ITEM, ITEM_UK), (ZONE_WAIT, ZONE_UK),
                 (E["prof"], txt(C.want(KEYS["prof"])))):
        C.names(lua_str(a), lua_str(b))

    def want(k):
        return txt(C.want(lua_str(KEYS[k])))

    def fill(k, *vals):
        return txt(C.fill(lua_str(KEYS[k]), *map(lua_str, vals)))

    def put(name, text):
        C.text(lua_str(name))
        return txt(C.set(lua_str(name), lua_str(text)))
    # Alts: the zone line.
    got = put("zone", E["zone"] % ZONE)
    check("code: Alts zone line, the zone from UALL Forever (no «<English zone>  -  у мережі»)",
          got == fill("zone", ZONE_UK), got)
    got = put("zone2", E["zone"] % ZONE_NONE)
    check("code: Alts zone line with a zone UALL Forever lacks stays English", got == E["zone"] % ZONE_NONE, got)
    # The Level line.
    got = put("lvl", E["level3"] % (42, RACE, CLASS))
    check("code: Level line with race and class from UALL Forever", got == fill("level3", "42", RACE_UK, CLASS_UK),
          got)
    got = put("lvl2", E["level"] % (42, CLASS_NONE))
    check("code: Level line with a class UALL Forever lacks stays English", got == E["level"] % (42, CLASS_NONE), got)
    C.hold(lua_str(ZONE_WAIT), True)
    first = put("wait", E["zone"] % ZONE_WAIT)
    C.hold(lua_str(ZONE_WAIT), False)
    M.wait(2.3)
    got = txt(C.get("wait"))
    check("code: a name UALL Forever says \"not now\" for: English first, ours after the retry",
          first == E["zone"] % ZONE_WAIT and got == fill("zone", ZONE_UK), (first, got))
    hub(check, M, C, E, want, fill)
    tips(check, C, E, want, fill)
    guards(check, M, C, E, want, put)
    F._errors(c, check, "code game")


def guards(check, M, C, E, want, put):
    """The worst UADD may do is leave a text English: an error inside our write, the game-wide hook."""
    a = put("safeA", E["prof"])
    put("safeB", E["notehead"])
    C.throwOnce(lua_str("safeB"))
    b = txt(C.set(lua_str("safeB"), lua_str(E["prof"])))
    M.uadd("mastercraft off")
    off = txt(C.get("safeA"))
    M.uadd("mastercraft on")
    on = txt(C.get("safeA"))
    check("code: an error inside our write leaves that text English, and off still gives English "
          "(busy reset on every path)", a == want("prof") and b == E["prof"] and off == E["prof"]
          and on == want("prof"), (a, b, off, on))
    n = C.forbidden()
    check("code: a forbidden frame's font string: its regions never asked for", n == 0, n)
    n = C.foreign()
    check("code: another addon's frame making 10 font strings is looked at twice at most", n <= 2, n)
    now, after = C.scan()
    check("code: the scan walks a few hundred frames per game frame, all of them in the end",
          now <= 300 and after == 600, (now, after))


def hub(check, M, C, E, want, fill):
    C.hub(lua_str(E["empty"]))

    def hs(which, text):
        return txt(C.hubSet(lua_str(which), lua_str(text)))
    profs = E["level"] % (42, CLASS) + " · " + E["prof"] + " " + WHITE + "300|r"
    cases = [("profs", profs, fill("level", "42", CLASS_UK) + " — " + want("prof") + " " + WHITE + "300|r"),
             ("note", E["notehead"] + ": " + NOTE, want("notehead") + ": " + NOTE),
             ("l1", GREY + E["empty"] + "|r", GREY + want("empty") + "|r"),
             ("l2", WHITE + E["avail"] % 3 + "|r", WHITE + fill("avail", "3") + "|r"),
             ("num", "3", "3"), ("name", PLAYER, PLAYER)]
    bad = [(w, got) for w, text, exp in cases if (got := hs(w, text)) != exp]
    check("code: Crafters hub raw strings: the line under the name, the note (its quotes kept), the empty "
          "tile, a count", not bad and C.hubCyr("profs") and C.hubCyr("l1"), bad[:2])
    bad = [(w, got) for w, text, exp in (
        ("note", E["nonote"], want("nonote")),
        ("l2", E["zonecount"] % 2, fill("zonecount", "2")),
        ("l1", E["canmake"] % (PLAYER, WHITE + ITEM + "|r"), fill("canmake", PLAYER, WHITE + ITEM_UK + "|r")),
        ("l2", E["canmake"] % (PLAYER, WHITE + ITEM_NONE + "|r"), E["canmake"] % (PLAYER, WHITE + ITEM_NONE + "|r")))
        if (got := hs(w, text)) != exp]
    check("code: Crafters hub: no note, in your zone, can make (an item UALL Forever lacks: English)",
          not bad, bad[:2])
    named = [(w, got) for w, text in (("l1", PLAYER), ("l2", E["prof"]), ("name", E["prof"]))
             if (got := hs(w, text)) != text]
    check("code: a favourite named like a Mastercraft text keeps the name (lesson 13)", not named, named[:2])
    hs("profs", profs)
    M.uadd("mastercraft off")
    off = txt(C.hubGet("profs"))
    M.uadd("mastercraft on")
    on = txt(C.hubGet("profs"))
    check("code: Crafters hub off: Mastercraft's English, on: ours again",
          off == profs and on == cases[0][2] and not C.hubCyr("name"), (off, on))


def tips(check, C, E, want, fill):
    def tip(text):
        return txt(C.tip(lua_str(text)))
    icon = "|TInterface\\Icons\\INV_Misc_QuestionMark:14|t"
    cases = [(E["each"] % "12s", fill("each", "12s")), (E["ea"] % "3s", fill("ea", "3s")),
             (E["likely"] + " 75%", want("likely") + " 75%"),
             (E["by"] % ("Hoba", E["prof"]), fill("by", "Hoba", want("prof"))),
             (E["de"] % (icon, ITEM, "2", ""), fill("de", icon, ITEM_UK, "2", ""))]
    bad = [(text, got) for text, exp in cases if (got := tip(text)) != exp]
    check("code: item tooltip lines: each, ea, a chance, crafted by, a disenchant row", not bad, bad[:2])
    got = tip(E["de"] % (icon, ITEM_NONE, "2", ""))       # "": the module left the line as it is
    check("code: disenchant row with an item UALL Forever lacks stays English", got == "", got)
