"""Edit Mode on the journal's home page and the glued quest titles (journal 2.1.5), in the DJ module flow.

Checked, each ours on, the exact English while Shift is held and with "/uadd dj off", ours again after: the
bar's four buttons and their tooltips, the View menu and the reset question left open over a switch (the
journal's own window, as with a controller), the note's text (its small OK keeps the English), the game's YES
and NO on the question's buttons and in the game's popup. The globals are never written. An OK button wide
enough is ours, a narrow one not, and one the journal has changed since is left alone. A quest title with a
name glued on, and the place tip with a dungeon's name: whole Ukrainian or whole English, also with made-up
names. Off gives the journal its own functions back. Ends on the home page, Edit Mode off."""
import os
import re

from flow_dj_screen import triple
from loader import lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
CYR = re.compile("[А-Яа-яІіЇїЄєҐґ]")
LATIN = re.compile("[A-Za-z]")
VIEW, ASK = "ForeverDungeonJournalViewMenu", "ForeverDungeonJournalResetUIAsk"


def ours(t):
    return bool(t) and all(CYR.search(p) and not LATIN.search(p) for p in t.split("|"))


def run(s, check, facts):
    s.lua.execute(read_text(os.path.join(HERE, "flow_dj_home.lua")))
    D, M = s.H.djhome, s.M
    wrapped = triple(D.own(), 2)

    def hold(on):
        M.key(on)
        M.wait(0.3)
        s.pump(5)

    def turns(name, read, english):
        """read() is ours; exact English held; ours on release; exact English off; ours on."""
        got = [read()]
        hold(True)
        got.append(read())
        hold(False)
        got.append(read())
        s.uadd("dj off")
        got.append(read())
        s.uadd("dj on")
        got.append(read())
        check(f"home: {name}: ours, English held, ours, English off, ours",
              ours(got[0]) and got == [got[0], english, got[0], english, got[0]], got)

    def tips():
        return "|".join(txt(D.tip(k)) for k in ("hide", "reorder", "view", "reset"))

    if not s.is_open():
        s.slash()
    s.click(s.frame.backButton)
    D.edit(True)
    s.pump(5)
    turns("the bar's buttons", lambda: txt(D.bar()), txt(D.barEnglish()))
    s.uadd("dj off")
    english_tips = tips()
    s.uadd("dj on")
    turns("the bar's tooltips", tips, english_tips)

    def view():                             # the menu shuts by itself 0.6 s after the mouse left it
        D.hide(VIEW)
        D.tool("view")
        s.pump(10)
        return txt(D.window(VIEW))

    got = [view()]
    hold(True)
    got.append(txt(D.window(VIEW)))
    D.hide(VIEW)
    hold(False)
    s.uadd("dj off")
    got.append(view())
    s.uadd("dj on")
    got.append(view())
    menu = txt(D.menuEnglish())
    check("home: the View menu: ours, held while open English, off English, on ours",
          ours(got[0]) and got == [got[0], menu, menu, got[0]], got)
    D.hide(VIEW)

    globals_before = txt(D.globals())
    yes, no, _ = globals_before.split("|")
    turns("the popup's YES and NO", lambda: txt(D.popup()), f"{yes}|{no}")
    D.controller(True)
    D.tool("reset")
    s.pump(10)
    turns("the reset window left open", lambda: txt(D.window(ASK)),
          f"{txt(D.en('RESET_UI_CONFIRM'))}|{yes}|{no}")
    D.hide(ASK)
    D.controller(False)
    D.edit(False)

    note = txt(D.note()) or ""
    s.pump(10)
    turns("the note", lambda: (txt(D.noteText()) or "").split("|")[0], txt(D.en("EDIT_MODE_NEW")))
    check("home: the note's small OK keeps the English", note.endswith("|" + globals_before.split("|")[2]), note)
    okay = globals_before.split("|")[2]
    wide, narrow = triple(D.okay(96), 2), triple(D.okay(40), 2)
    check("home: an OK with room is ours, English again; a narrow one stays",
          ours(txt(wide[0])) and txt(wide[1]) == okay and [txt(v) for v in narrow] == [okay, okay], (wide, narrow))
    check("home: an OK the journal has changed since is left alone",
          txt(triple(D.okay(96, "Wobbly"), 2)[1]) == "Wobbly")
    check("home: the game's words are never written", txt(D.globals()) == globals_before, txt(D.globals()))

    whole, uk, en, bad = triple(D.titles(), 4)
    facts["dj_glued_titles"] = f"{uk} Ukrainian, {en} English"
    check("home: every glued quest title whole", bool(whole), txt(bad))
    item = (lua_str("Zorp Blatter"), lua_str("Річ"))
    got = [txt(D.title(8962, lua_str("Назва"), *item)), txt(D.title(8962, lua_str("Назва"))),
           txt(D.title(8962, None, *item))]
    check("home: title and item known: whole Ukrainian", got[0] == "Назва (Річ)", got)
    check("home: an item or a title nobody has: whole English", not CYR.search(got[1] + got[2])
          and got[1].endswith("(Wobbly Gizmo)"), got)

    key, name = (txt(v) for v in triple(D.dungeon(), 2))
    place = [txt(D.place(lua_str(name))), txt(D.place(lua_str("Wobbly Gizmo")))]
    tip = txt(D.en("REORDER_PLACE_TIP"))
    check("home: the place tip with a known dungeon is ours", ours(place[0]) and name in place[0], place)
    check("home: with one nobody has it is whole English", place[1] == tip % "Wobbly Gizmo", place)
    hold(True)
    held = txt(D.place(lua_str(name)))
    hold(False)
    check("home: held with a name picked before: whole English", held == tip % key, held)

    s.uadd("dj off")
    check("home: off gives the journal's own functions back", not D.sameOwn(*wrapped))
    off = triple(D.own(), 2)
    s.uadd("dj on")
    check("home: on wraps them again", D.sameOwn(*wrapped) and not D.sameOwn(*off))
