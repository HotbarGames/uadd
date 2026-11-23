"""Made-up values, shapes and read-back helpers for the half-translation check of some modules
(halves_mods.py uses them): DialogueUI's names by kind, Attune's slot values, OpenMap's own shapes,
and reading a text back into its slot values (Dungeon Journal, Bagnon).
"""
import re

from loader import lua_str, txt

NAME = "Quix"

# DialogueUI: a name of its kind for a slot Slots.lua marks (an item link, a key binding).
DUI_FREE = {"item": "|cff1eff00|Hitem:2140::::::::60:::::|h[Quix]|h|r", "key": "QUIX"}

# Attune: its locale texts with a slot, read from the module's own pairs.
ATT_LUA = r"""
local ns, out = HARNESS.ns.UADD_Attune, {}
ns.Pairs(function(en, uk, key)
  if type(en) == "string" and type(uk) == "string" and uk ~= "" and uk ~= en
      and (en:find("%s", 1, true) or en:find("##%u[%u%d_]*##")) then out[#out + 1] = { en, key or false } end
end)
return out
"""
ATT_FREE = {"value": "7", "player": NAME, "target": NAME}
ATT_BY_KEY = {"WHAT": "Guild"}   # a place Attune fills with the text of one of its own keys (its real value)

# Words.lua's own shapes around a name ("Level %s", the card's "Name, Name", a dungeon and its levels),
# in colour pieces, and as OpenMap's Map/Dungeons.lua builds them: its English around L's words (ours,
# so Ukrainian) and a level range in colour. Then the lines OpenMap builds from L's words and its own
# parts (Parts.lua): a note's and a pin's title, a pin row and the dock's
# "To" (both forms) with a zone name.
RFK, RANGE = "Razorfen Kraul", "|cffff804024-33|r"
OM_SHAPES = (("Level %s", {}), ("%s, %s", {1: RFK, 2: RFK}), ("%s  %d-%d", {1: RFK}),
             ("Floor 1 |cffffffff%s|r", {}), ("|cffffd100%s|r %s", {1: RFK, 2: RFK}),
             ("|cffffd100%s|r  |cff998866%d / %d|r", {1: "Floor 1"}),
             ("Level %s   |cffbbbbbb%s|r", {1: RANGE, 2: "Raid"}), ("Level %s   |cffbbbbbbРейд|r", {1: RANGE}),
             ("Level %s  (від 20)", {}), ("|cffffd100%s  %s, %s  %s|r", {1: RFK, 2: RANGE, 3: RFK, 4: RANGE}),
             ("|cffe6c27a%s|r  |cff998866(Questie)|r", {1: "Quests"}), ("|cff808080%s|r", {1: "done"}),
             ("Нова нотатка · %s", {1: RFK}),
             ("Нотатка #%d · %s", {2: RFK}), ("%s · |cffffffffmy note|r |cffe6c27a(малюнок)|r", {1: RFK}),
             ("Мітка · %s  %.1f, %.1f", {1: RFK}), ("Куди: %s", {1: RFK}), ("To %s", {1: RFK}))
# The World Map's hover label as OpenMap writes it (Label.lua): a zone and its level range in colour.
OM_LABEL = (("%s |cffff8040(%d-%d)|r", {1: RFK}), ("%s |cff40c040(%d)|r", {1: RFK}))


def parts(en, text):
    """The slot values of `text` read back by the English template `en` (all %s), or None."""
    m = re.match("^" + "(.*?)".join(re.escape(p) for p in en.split("%s")) + "$", text, re.S)
    return [lua_str(v) for v in m.groups()] if m else None


def named(v):
    """An item part of the joined-item line, "Name (Boss)": (name, boss or None)."""
    m = re.match(r"^(.*) \(([^()]*)\)$", txt(v))
    return (lua_str(m[1]), lua_str(m[2])) if m else (v, None)


def bgn_value(s):
    """A number, or money as the game writes it (digits and coin icons, maybe coloured)."""
    s = re.sub(r"\|T[^|]*\|t|\|c[0-9a-fA-F]{8}|\|r", "", s)
    return re.fullmatch(r"[\d\s.,]+", s) is not None
