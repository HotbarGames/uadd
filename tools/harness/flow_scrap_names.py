"""UADD_Scrap: item names in the junk list come from UALL Forever (UADD_Scrap/Items.lua), on the Scrap stand-in
(tools/harness/scrap). UALL Forever is a stand-in too (UADD.UALL.Item answers from a table set here):

  1. A name it has: the row shows its Ukrainian, in our font (read back). 2. A name it lacks (the item named like
  a tab) stays English. 3. "Not now": English, then Ukrainian at the list's next update. 4. A row that shows
  another item next shows that item's name, not the last one's Ukrainian. 5. Hold key and off: English at once
  and after the list's next update; key up and on: Ukrainian again. 6. No Lua errors.
"""
import flow_scrap as fs
from flow_pawn_game import errors
from loader import lua_str, txt

UK = "Клинок Квікса"           # made up: what the stand-in UALL Forever says for the made-up "Quix Blade"
STUB = """
local N = { names = {}, later = {} }
HARNESS.scrapNames = N
UADD.UALL.Item = function(en) if N.later[en] then return nil, true end return N.names[en] end
function N.shown()
    local out = {}
    for i, b in ipairs(Scrap.Visualizer.items) do out[i] = b.Text:GetText() end
    return out
end
function N.rows() Scrap.Visualizer.Scroll.update() return N.shown() end
function N.cyrFont(i) return UADD.IsCyrFont((Scrap.Visualizer.items[i].Text:GetFont())) and true or false end
function N.rename(i, name) Scrap.Visualizer.items[i].name = name end
"""


def run(check, facts):
    if not fs.module_there() or not fs.installed():
        return
    code, _ = fs.words()
    c, M = fs.game(code)
    c.lua.execute(STUB)
    N = c.H.scrapNames
    blade = lua_str("Quix Blade")
    N.names[blade] = lua_str(UK)
    N.later[blade] = True

    def rows(update=True):
        return [txt(x) for x in (N.rows() if update else N.shown()).values()]
    first = rows()
    check("names 3: 'not now' stays English at first", first[0] == "Quix Blade", first)
    N.later[blade] = None
    on = rows()
    check("names 3+1: then UALL Forever's Ukrainian, in our font", on[0] == UK and N.cyrFont(1), on)
    check("names 2: a name it lacks stays English", on[1] == txt(code[-1]), on)
    for step, act, want in (("hold key down", lambda: M.key(True), first),
                            ("hold key up", lambda: M.key(False), on),
                            ("/uadd scrap off", lambda: M.uadd("scrap off"), first),
                            ("/uadd scrap on", lambda: M.uadd("scrap on"), on)):
        act()
        c.H.pump(5)
        now, later = rows(False), rows()
        font = N.cyrFont(1)
        check(f"names 5: {step} (font too)", now == want and later == want and font == (want is on), (now, later, font))
    N.rename(1, "Quix Cloak")
    now = rows()
    check("names 4: a row with another item shows that item's name", now[0] == "Quix Cloak", now)
    errors(c, check, "names")
