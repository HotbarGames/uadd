"""What the owner's shots showed English or as boxes in LiteMount (2026-11-21), and the game names in its lists:
a box check (no Cyrillic drawn in a font without it under LiteMount's frames), the page titles and the search
box's hint, the counts line and the macro's character count, priority 0 and 4, the Falling rows' Delete, and the
mount, spell and item names (asked of UALL Forever / ClassicUA, never ours). Each step: ours, English while held,
ours, English off, ours. Called from flow_litemount.py (game A and its mutants); Lua helpers:
flow_litemount_shots.lua, the stand-in's part: litemount/Shots.lua.
"""
import os

import flow_litemount_steps as S
from loader import lua_str, read_text

HERE = os.path.dirname(os.path.abspath(__file__))
LUA = os.path.join(HERE, "flow_litemount_shots.lua")

STEPS = {
    "sboxes": "9 no Cyrillic in a font without it on LiteMount's panels (the Profiles buttons, titles, rows, names)",
    "spages": "9 the page titles, the search box's hint, the macro tabs and labels ours, English while held and off",
    "scounts": "9 the counts line and the macro's character count ours (also when set again), English held and off",
    "sprio": "9 priority 0 and 4 (Disable, Always) ours, English while held and off",
    "srows": "9 each Falling row's Delete ours (rows made after login too), English while held and off",
    "snames": "9 mount, spell and item names from UALL Forever in the Mounts and Falling lists (unknown ones and a "
              "slot row English, a row used again), English while held and off",
    "slater": "9 a name UALL Forever cannot give yet stays English and is asked again later",
    "sgiveup": "9 a text no Cyrillic font can take (a secure button's label, a name the box guard gave up on) shows "
               "its whole English, also when LiteMount sets ours again, held and off",
}
S.STEPS.update(STEPS)

# The installed LiteMount sets these the way litemount/Shots.lua does.
CODE = (("UI/MountListButtonTemplate.lua", "    self.Name:SetText(mount.name)"),
        ("UI/MountListButtonTemplate.lua", "    LiteMountMountCommonButtonMixin.Initialize(self, mount, hasMenu)"),
        ("UI/Falling.lua", "                    self.Name:SetText(info.name)"),
        ("UI/Falling.lua", "                    self.Name:SetText(item:GetItemName())"),
        ("UI/Falling.lua", "function LiteMountItemSpellMixin:Initialize(elementData, DeleteCallback)"))

UK, EN = lua_str("uk"), lua_str("en")
ROWS = ("spell:130", "spell:2", "item:3", "slot:15")


def load(c):
    c.lua.execute(read_text(LUA))


def setup(M):
    """After login: UALL Forever's stand-in, the Falling rows and two mounts (one not collected)."""
    M.shotStub(None)
    for r in ROWS:
        M.shotRow(lua_str(r))
    M.shotMount(lua_str("Quix Strider"), True)
    M.shotMount(lua_str("Quix Raptor"), False)


def _both(check, M, step, now, expect):
    got = S._ways(M, now)
    u, e = expect(UK), expect(EN)
    want = [u, e, u, e, u]
    ok = None not in (u, e) and u != e and S.cyr(str(u)) and got == want
    check(S.STEPS[step], ok, {"got": got[:4], "want": want[:2]})
    return ok


def boxes(check, M):
    got = [S.tx(M.shotBoxes())]
    S.press(M, True)
    got.append(S.tx(M.shotBoxes()))
    S.press(M, False)
    got.append(S.tx(M.shotBoxes()))
    ok = got == ["", "", ""]
    check(S.STEPS["sboxes"], ok, {"got": got})
    return ok


def pages(check, M):
    return _both(check, M, "spages", lambda: S.tx(M.shotTexts()), lambda w: S.tx(M.shotTextsExpect(w)))


def counts(check, M):
    return _both(check, M, "scounts", lambda: S.tx(M.shotCounts()), lambda w: S.tx(M.shotCountsExpect(w)))


def prio(check, M):
    return _both(check, M, "sprio", lambda: S.tx(M.shotPrio()), lambda w: S.tx(M.shotPrioExpect(w)))


def rows(check, M):
    M.shotRow(lua_str("spell:130"))
    return _both(check, M, "srows", lambda: S.tx(M.shotRows()), lambda w: S.tx(M.shotRowsExpect(w)))


def names(check, M):
    M.shotReuse(4, lua_str("item:3"))          # a slot row used again for an item
    M.shotReuse(3, lua_str("slot:15"))         # an item row used again for a slot: English
    return _both(check, M, "snames", lambda: S.tx(M.shotNames()), lambda w: S.tx(M.shotNamesExpect(w)))


def later(check, M):
    M.shotStub(lua_str("later"))
    b = M.shotMount(lua_str("Quix Lynx"), True)
    first = S.tx(b.Name.GetText(b.Name))
    M.shotStub(None)
    b.Initialize(b, b.mount)
    second = S.tx(b.Name.GetText(b.Name))
    ok = first == "Quix Lynx" and S.cyr(second)
    check(S.STEPS["slater"], ok, {"first": first, "second": second})
    return ok


def giveup(check, M):
    named, _, first = S.tx(M.shotGiveUp()).partition(" ## ")
    want = S.tx(M.shotGiveUpExpect())
    got = [first] + S._ways(M, lambda: S.tx(M.shotGiveUpNow()))[1:]
    ok = S.cyr(named) and got == [want] * 5
    check(S.STEPS["sgiveup"], ok, {"named": named, "got": got, "want": want})
    return ok


def steps(check, M):
    setup(M)
    for f in (boxes, pages, counts, prio, rows, names, later, giveup, boxes):
        f(check, M)


def _reach(f):
    return lambda q, c, M: (setup(M), f(q, M))


# cut -> (the sub-check it must break, how to build its game, how to reach it on a fresh game).
MUTANTS = {
    "sfont": ("sboxes", {}, _reach(boxes)),
    "sgiveup": ("sgiveup", {}, _reach(giveup)),
    "spages": ("spages", {}, _reach(pages)),
    "shint": ("spages", {}, _reach(pages)),
    "scounts": ("scounts", {}, _reach(counts)),
    "schars": ("scounts", {}, _reach(counts)),
    "sprio": ("sprio", {}, _reach(prio)),
    "srows": ("srows", {}, _reach(rows)),
    "smounts": ("snames", {}, _reach(names)),
    "sfalling": ("snames", {}, _reach(names)),
    "skind": ("snames", {}, _reach(names)),
}
