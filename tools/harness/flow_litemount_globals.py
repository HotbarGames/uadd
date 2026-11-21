"""Game globals LiteMount shows on its own frames (owner's shots, 2026-11-21): the Rules and Falling page names,
its buttons (Add, Delete, Revert, Defaults, ...), "Key Binding n" in the Rules and Advanced dropdowns, and the
conditions named by a global (Instance, Level, Map, Falling). Each is ours there while the global is English,
English while held and off, and the global itself is never written. Called from flow_litemount.py (game A and
its mutants); Lua helpers: flow_litemount_globals.lua, the stand-in's part: litemount/Globals.lua.
"""
import os

import flow_litemount_steps as S
from loader import lua_str, read_text

HERE = os.path.dirname(os.path.abspath(__file__))
LUA = os.path.join(HERE, "flow_litemount_globals.lua")

STEPS = {
    "gpages": "3 the Rules and Falling page names (title, settings category) ours, English while held and off",
    "gbuttons": "3 its buttons named by a game global (Add, Delete, Edit, Rename, Cancel, Okay, Revert, Defaults) "
                "ours, English while held and off",
    "gbind": "3 \"Key Binding n\" in the Rules and Advanced dropdowns ours (shown and in the menu), English while "
             "held, their generator back when off",
    "gconds": "3 rule lines named by a game global (Instance, Level, Map, Falling) ours; with a place name in "
              "English the whole line English",
    "gcyr": "3 a game global already Cyrillic (ADD, KEY_BINDING) is left as it is on its buttons and dropdowns",
}
S.STEPS.update(STEPS)

# The installed LiteMount builds these from the globals the way litemount/Globals.lua does.
CODE = (("UI/Rules.lua", "    return format('%s %s', KEY_BINDING, n)"),
        ("UI/Rules.lua", "self.BindingDropDown:SetupMenu(BindingGenerator)"),
        ("UI/Advanced.lua", "    return format('%s %s', KEY_BINDING, n)"),
        ("UI/Advanced.lua", "self.BindingDropDown:SetupMenu(BindingGenerator)"),
        ("UI/Rules.xml", '<KeyValue key="name" value="BRAWL_TOOLTIP_RULES" type="global" />'),
        ("UI/Falling.xml", '<KeyValue key="name" value="STRING_ENVIRONMENTAL_DAMAGE_FALLING" type="global" />'),
        ("Conditions.lua", "name = INSTANCE,"), ("Conditions.lua", "name = LEVEL,"),
        ("Conditions.lua", "name = BRAWL_TOOLTIP_MAP,"), ("Conditions.lua", "name = STRING_ENVIRONMENTAL_DAMAGE_FALLING,"),
        ("UI/PanelTemplate.xml", 'text="SETTINGS_DEFAULTS"'), ("UI/PanelTemplate.xml", 'text="REVERT"'),
        ("UI/Rules.xml", 'text="ADD"'))

UK, EN = lua_str("uk"), lua_str("en")


def load(c):
    c.lua.execute(read_text(LUA))


def _both(check, M, step, now, expect):
    """now() at login, held, released, off, on: ours, English, ours, English, ours."""
    got = S._ways(M, now)
    u, e = expect(UK), expect(EN)
    want = [u, e, u, e, u]
    ok = None not in (u, e) and S.cyr(str(u)) and got == want
    check(S.STEPS[step], ok, {"got": got[:4], "want": want[:2]})
    return ok


def pages(check, M):
    return _both(check, M, "gpages", lambda: S.tx(M.pages()), lambda w: S.tx(M.pagesExpect(w)))


def buttons(check, M):
    return _both(check, M, "gbuttons", lambda: S.tx(M.buttons()), lambda w: S.tx(M.buttonsExpect(w)))


def conds(check, M):
    return _both(check, M, "gconds", lambda: S.tx(M.conds()), lambda w: S.tx(M.condsExpect(w)))


def bind(check, M):
    got = S._ways(M, lambda: (S.tx(M.bind()), bool(M.bindTheirs())))
    u, e = S.tx(M.bindExpect(UK)), S.tx(M.bindExpect(EN))
    want = [(u, False), (e, False), (u, False), (e, True), (u, False)]
    ok = None not in (u, e) and S.cyr(u) and got == want
    check(S.STEPS["gbind"], ok, {"got": got, "want": want[:4]})
    return ok


def cyr(check, M):
    """ADD and KEY_BINDING already Cyrillic (another Ukrainian addon): their texts stay as they are, on and off."""
    add, key = lua_str("ADD"), lua_str("KEY_BINDING")
    was = {g: S.tx(M.setGlobal(g, None)) for g in (add, key)}
    M.setGlobal(add, lua_str("Плюс"))
    M.setGlobal(key, lua_str("Клавіша"))
    M.setButtons(add, lua_str("Плюс"))
    got = []
    for msg in ("litemount off", "litemount on"):
        S.uadd(M, msg)
        got.append((S.tx(M.buttonsOf(add)), S.tx(M.bind())))
    n = len(S.tx(M.buttonsOf(add)).split(" | "))
    want = (" | ".join(["Плюс"] * n), S.tx(M.bindExpect(EN, lua_str("Клавіша"))))
    for g, v in was.items():
        M.setGlobal(g, lua_str(v))
    M.setButtons(add, lua_str(was[add]))
    S.uadd(M, "litemount off")
    S.uadd(M, "litemount on")
    ok = got == [want, want]
    check(S.STEPS["gcyr"], ok, {"got": got, "want": want})
    return ok


def steps(check, M):
    for f in (pages, buttons, bind, conds, cyr):
        f(check, M)


# cut -> (the sub-check it must break, how to build its game, how to reach it on a fresh game).
MUTANTS = {
    "gpages": ("gpages", {}, lambda q, c, M: pages(q, M)),
    "gback": ("gpages", {}, lambda q, c, M: pages(q, M)),
    "gbuttons": ("gbuttons", {}, lambda q, c, M: buttons(q, M)),
    "gbind": ("gbind", {}, lambda q, c, M: bind(q, M)),
    "gbindback": ("gbind", {}, lambda q, c, M: bind(q, M)),
    "gcond": ("gconds", {}, lambda q, c, M: conds(q, M)),
    "gfields": ("gconds", {}, lambda q, c, M: conds(q, M)),
    "gcyr": ("gcyr", {}, lambda q, c, M: cyr(q, M)),
}
