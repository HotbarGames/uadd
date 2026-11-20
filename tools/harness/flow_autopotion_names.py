"""UADD_AutoPotion: game names on Auto Potion's Heal page come from UALL Forever (UADD_AutoPotion/Game.lua), on the
stand-in (tools/harness/autopotion) with a class header per class and spell and item check boxes added here, the
way Auto Potion's createSpellSection lays them out. UALL Forever is a stand-in too (UADD.UALL.Class, .Spell and
.Item answer from tables set here); every name is made up but the two class names, which are the game's own:

  1. A name it has: the class header, a spell box and an item box show its Ukrainian, in our font (read back).
  2. A name it lacks (a class, a spell) stays English, whole.
  3. "Not now" (a class): English, not asked again within a second, then Ukrainian the next time the page shows.
  4. Hold key and off: English; key up and on: Ukrainian again. 5. No Lua errors.
"""
import flow_autopotion as fa
from flow_autopotion_uk import txt
from loader import lua_str

UK = {"Mage": "Маг", "Quix Tide": "Приплив Квікса", "Quix Draught": "Настій Квікса"}
STUB = """
local N = { names = { Class = {}, Spell = {}, Item = {} }, later = {}, asked = {}, fs = {} }
HARNESS.apNames = N
LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", WARLOCK = "Warlock" }
for _, route in ipairs({ "Class", "Spell", "Item" }) do
    UADD.UALL[route] = function(en)
        N.asked[en] = (N.asked[en] or 0) + 1
        if N.later[en] then return nil, true end
        return N.names[route][en]
    end
end
local heal = AutoPotionStandIn.pages.Heal
local function Header(text)
    local fs = heal:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    fs:SetText(text)
    return fs
end
local function Box(text)
    local b = CreateFrame("CheckButton", nil, heal, "InterfaceOptionsCheckButtonTemplate")
    if not b.Text then
        b.Text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        b:SetFontString(b.Text)
    end
    b.Text:SetText(text)
    return b.Text
end
N.fs = { Header("Mage"), Box("Quix Tide"), Box("Quix Draught"), Box("Quix Gloom"), Header("Warlock") }
function N.shown()
    local out = {}
    for i, fs in ipairs(N.fs) do out[i] = fs:GetText() end
    return out
end
function N.cyrFont(i) return UADD.IsCyrFont((N.fs[i]:GetFont())) and true or false end
"""
ENGLISH = ["Mage", "Quix Tide", "Quix Draught", "Quix Gloom", "Warlock"]


def run(check, facts):
    c, M = fa._game([fa.STAND_IN, fa._addon("UADD"), fa._addon(fa.MODULE)], fa.english())
    c.lua.execute(STUB)
    N = c.H.apNames
    routes = {"Mage": "Class", "Quix Tide": "Spell", "Quix Draught": "Item"}
    for en, uk in UK.items():
        N.names[routes[en]][lua_str(en)] = lua_str(uk)
    N.later[lua_str("Mage")] = True
    M.settings(True)

    def show():
        M.page("Heal", False)
        M.page("Heal", True)
        c.H.pump(5)
        return [txt(x) for x in N.shown().values()]
    first = show()
    check("names 3: a class name 'not now' stays English at first", first[0] == "Mage", first)
    check("names 1: spell and item boxes from UALL Forever, in our font",
          first[1:3] == [UK["Quix Tide"], UK["Quix Draught"]] and N.cyrFont(2) and N.cyrFont(3), first)
    N.later[lua_str("Mage")] = None
    soon = show()
    check("names 3: not asked again within a second of 'not now' (no garbage)", soon[0] == "Mage", soon)
    c.H.time = c.H.time + 1.1
    on = show()
    check("names 3+1: the class header after 'not now', in our font", on[0] == UK["Mage"] and N.cyrFont(1), on)
    check("names 2: a spell and a class UALL Forever lacks stay English", on[3:] == ENGLISH[3:], on)
    asked = {txt(k): int(v) for k, v in N.asked.items()}
    check("names: UALL Forever asked for each game name shown", all(asked.get(w) for w in ENGLISH), asked)
    for step, act, want in (("hold key down", lambda: M.key(True), ENGLISH),
                            ("hold key up", lambda: M.key(False), on),
                            ("/uadd autopotion off", lambda: M.uadd("autopotion off"), ENGLISH),
                            ("/uadd autopotion on", lambda: M.uadd("autopotion on"), on)):
        act()
        c.H.pump(5)
        now = [txt(x) for x in N.shown().values()]
        again = show()
        font = N.cyrFont(2)
        check(f"names 4: {step} (font too)", now == want and again == want and font == (want is on),
              (now, again, font))
    fa._errors(c, check, "names")
