"""Steps 9-11 of flow_gq.py (UADD_GearQuestForever, Menu.lua), each (check, g) -> ok: the right-click menu on a hunt in
the game's shared list, the box to copy a name, the short notices. Their cuts go into CUTS of flow_gq.py. Keys only:
the English comes from the installed addon (g.ref["en"])."""
from flow_pawn_game import cyr
from loader import lua_str, txt

MENU = ["L.9be0861d", "L.a97540e1", "L.0e2f377a", "L.766f00af", "L.33ea0d4a", "L.cb609b81"]
TITLE = "L.59a1f975"
NOTICES = ["L.d095059b", "L.16eb5316", "L.5e32d8a7", "L.e71a8549"]
HOWS = ("hold", "release", "off", "on")


def feed(en):
    """What the stand-in shows: the words of the menu's rows and of the box's title."""
    return {"menu": [en[k] for k in MENU], "copy": en[TITLE]}


def _parts(M):
    return {txt(k): txt(v) for k, v in M.parts().items()}


def _fonts(M):
    return [txt(x) for x in M.partFonts().values()]


def _turn(M, how):
    if how in ("hold", "release"):
        M.key(how == "hold")
    else:
        M.uadd("gq " + how)
    M.wait(0.1)


def _loop(M, pre, en):
    """Ours now; English exactly held and off, ours again after; the fonts with it. The bad ones."""
    A, bad = {k: v for k, v in _parts(M).items() if k.startswith(pre)}, []
    if set(A) != set(en) or not all(cyr(v) for v in A.values()) or _fonts(M):
        bad.append(("ours", A, _fonts(M)[:2]))
    for how in HOWS:
        _turn(M, how)
        got = {k: v for k, v in _parts(M).items() if k.startswith(pre)}
        want = en if how in ("hold", "off") else A
        if got != want or _fonts(M):
            bad.append((how, got, _fonts(M)[:2]))
    return bad


def menu(check, g):
    M, en = g.M, g.ref["en"]
    E = {"M:%d" % i: en[k] for i, k in enumerate(MENU, 1)}
    M.hunt(lua_str("Zorp Helm"))
    bad = _loop(M, "M:", E)
    M.hideMenu()
    if _parts(M) != E or _fonts(M):
        bad.append(("hidden", _parts(M), _fonts(M)[:2]))
    M.uadd("gq off")                                 # opened while off, then on with it open
    M.hunt(lua_str("Zorp Helm"))
    off = _parts(M) == E
    M.uadd("gq on")
    if not off or not all(cyr(v) for v in _parts(M).values()) or _fonts(M):
        bad.append(("opened off, then on", off, _parts(M), _fonts(M)[:2]))
    # Another addon's menu over ours, with the English of a word of ours.
    M.otherMenu(lua_str(en[MENU[1]]), lua_str("wobbly gizmo"))
    other = {"M:1": en[MENU[1]], "M:2": "wobbly gizmo"}
    for how in (None,) + HOWS:
        if how:
            _turn(M, how)
        if _parts(M) != other or _fonts(M):
            bad.append(("other menu", how, _parts(M), _fonts(M)[:2]))
    M.hideMenu()
    check("9 right-click menu: ours, English held and off, ours again; hidden: the shared rows English on their own "
          "font; another addon's menu with the same English untouched", not bad, bad[:2])
    return not bad


def copy(check, g):
    M, en = g.M, g.ref["en"]
    name = en[MENU[1]]                               # a name that is the English of a word of ours: kept as it is
    M.copy(lua_str(name))
    bad = _loop(M, "C:", {"C:title": en[TITLE]})
    if txt(M.edit()) != name:
        bad.append(("edit", txt(M.edit())))
    check("10 copy box: its title ours, English held and off, ours again; the name in its text box untouched",
          not bad, bad[:2])
    return not bad


def notice(check, g):
    M, en, bad = g.M, g.ref["en"], []
    for k in NOTICES:
        M.notice(lua_str(en[k]))
        bad += _loop(M, "N:", {"N:text": en[k]})
        if not M.noticeFits():
            bad.append((k, "does not fit"))
    # A longer line of its table, so that the size depends on the text (a notice's own lines stay at its least width).
    long = [k for k, v in en.items() if k.startswith("L.") and 30 <= len(v) <= 50 and not set(v) & set("%|\n")]
    for k in sorted(long)[:6]:
        M.notice(lua_str(en[k]))
        for how in (None,) + HOWS:
            if how:
                _turn(M, how)
            if not M.noticeFits():
                bad.append((k, how, "does not fit"))
    M.key(True)
    M.notice(lua_str(en[NOTICES[0]]))              # drawn while held: its English on its own font
    if _parts(M).get("N:text") != en[NOTICES[0]] or _fonts(M) or not M.noticeFits():
        bad.append(("drawn held", _parts(M), _fonts(M)[:2]))
    M.key(False)
    check("11 notices: ours, sized to our font, English held and off, ours again; one drawn while held English",
          not bad, bad[:2])
    return not bad


CUTS = {
    "menu": ("Menu.lua", "        hooksecurefunc(\"ToggleDropDownMenu\", G.Guard(OnMenu))\n", "", "menu"),
    "menuhide": ("Menu.lua", "        pcall(U.CyrUnfix, fs, kept)\n    end\nend\n", "    end\nend\n", "menu"),
    "menusync": ("Menu.lua", "function() if next(rows) ~= nil then SyncRows(on) end end", "function() end", "menu"),
    "menuowner": ("Menu.lua", "frame == nil or frame ~= rawget(_G, MENU)", "frame == nil", "menu"),
    "copytitle": ("Menu.lua", '    Hook("Log", "CopyHuntName", SyncTitle)\n', "", "copy"),
    "notice": ("Menu.lua", '    Hook("Orders", "ShowNotice", SyncNotice)\n', "", "notice"),
    "noticefit": ("Menu.lua", "    frame:SetWidth(math.max(240, math.min(520, w)))\n", "", "notice"),
}
