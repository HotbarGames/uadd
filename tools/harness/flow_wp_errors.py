"""One more step of flow_wp.py: five errors in its own hooks turn the module off, then "/uadd waypointui on": its hooks
work again and the English comes back, held and off (lesson 19: they run under a Guard, not U.Safe)."""
from flow_wp_steps import put, t, w
from loader import lua_str, txt


def guard(check, M, p):
    M.wait(3.5)                                 # past UADD's settle time after login
    en, uk = (p["button"], p["input"]), (w(M, p["button"]), w(M, p["input"]))

    def putf(name, v): return txt(M.setf(lua_str(name), lua_str(v)) or "")  # noqa: E704

    def both(): return t(M, "button"), t(M, "input")  # noqa: E704
    put(M, "button", en[0])
    putf("input", en[1])
    start = both()
    M.trip(True)
    one = put(M, "button", en[0])
    for _ in range(2):
        put(M, "button", en[0])
        putf("input", en[1])
    M.trip(False)
    M.wait(0.3)
    said = "вимкнено до кінця сесії" in txt(M.lastChat(4))
    off = (M.on(), both())
    ok_off = start == uk and one == en[0] and said and off == (False, en)
    check("15 five errors in its own hooks: whole English on an error, then the module off, English back (lesson 19)",
          ok_off, (start, one, said, off))
    put(M, "button", "Zorp")
    M.uadd(lua_str("waypointui on"))
    M.wait(0.3)
    on = both()
    fresh = (put(M, "button", en[0]), putf("input", en[1]), put(M, "dist", "21 yds"))
    put(M, "input", "Blatter")                  # the addon's own text, then the English again
    again = (t(M, "input"), put(M, "input", en[1]))
    M.key(True)
    held = both()
    put(M, "button", p["grey"])                 # set while held: English, ours on release
    grey = t(M, "button")
    M.key(False)
    after = both()
    put(M, "button", en[0])
    ok_on = (M.on() and on == ("Zorp", uk[1]) and fresh == (*uk, "21 ярд") and again == ("Blatter", uk[1])
             and held == en and grey == p["grey"] and after == (w(M, p["grey"]), uk[1]))
    check("15 on again: each text it sets is ours, English while held, ours on release", ok_on,
          (on, fresh, again, held, grey, after))
    M.updateFonts(None, lua_str("OUTLINE"), lua_str("THICKOUTLINE"))
    ok_font = M.cyr(lua_str("footer")) and M.cyr(lua_str("pinpoint"))
    check("15 on again: fonts it sets anew get the Cyrillic file again", ok_font, txt(M.font(lua_str("footer"))[0]))
    M.open()
    M.wait(0.2)
    rows = [t(M, f"set{i}") for i in range(1, len(p["settings"]) + 1)]
    M.tab(lua_str(p["tab"]), lua_str("tab1"))
    M.wait(1.2)
    tab = t(M, "tab1")
    M.close()
    ok_set = rows == [w(M, x) for x in p["settings"]] and tab == w(M, p["tab"])
    check("15 on again: its settings, first shown now, and a tab built later are ours", ok_set, (rows[:2], tab))
    M.uadd(lua_str("waypointui off"))
    back = both()
    while_off = put(M, "button", p["grey"])
    M.uadd(lua_str("waypointui on"))
    ok_back = back == en and while_off == p["grey"] and t(M, "button") == w(M, p["grey"])
    check("15 off: English back, a text set while off stays English; on: ours", ok_back, (back, while_off, t(M, "button")))
    return ok_off and ok_on and ok_font and ok_set and ok_back
