"""UADD_OpenMap on OpenMap's questions in the game's StaticPopup dialogs (UADD_OpenMap/Popup.lua):
pins someone shared, delete all pins, the report's second step and ClassicUI Forever's World map option.

Each is whole Ukrainian in a font with Ukrainian letters: texts OpenMap took from L as it asked and
the ones it read as its files loaded (its buttons, the report's text). The shared pins' zones and
notes stay exactly as they came, on, held and off. The hold key gives OpenMap's English (the font
stays only on a text that still has Ukrainian letters: a player's note); a hidden dialog gets the
game's fonts back, so another addon's question in it is as before; "/uadd openmap off" puts the
English and the fonts back exactly. Called from flow_openmap.in_game; Lua helpers in
flow_openmap_popup.lua.
"""
import os

import session
from loader import lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
HELD = 0.3
NOTES = "Orgrimmar: біля входу\nIronforge: near the bank"   # the players' notes: kept as written


def _texts(P, i):
    return txt(P.texts(i)).split("\t")


def _fonts(P, i):
    return txt(P.fonts(i)).split("\t")


def run(s, check):
    s.lua.execute(read_text(os.path.join(HERE, "flow_openmap_popup.lua")))
    P, M = s.H.omp, s.H.om
    P.hideAll()
    P.other()
    i = P.of("OTHER_ADDON_QUESTION")
    game = _fonts(P, i)                       # the dialog's fonts as the game has them
    P.hideAll()

    P.shared("Quix", lua_str(NOTES), 2)
    i = P.of("OPENMAP_PINS_SHARED")
    got = _texts(P, i)
    rest = "\n|cffffffff" + NOTES + "|r"
    check("popup: shared pins in Ukrainian, the notes exactly as written",
          got == ["Quix ділиться з вами позначками (2):" + rest, "Додати", "Ігнорувати"], got)
    check("popup: shared pins in a font with Ukrainian letters", txt(P.cyr(i)) == "111", txt(P.cyr(i)))
    h, th = P.heights(i)
    check("popup: the dialog sized to the Ukrainian text", h == 60 + th, [h, th])
    boxes = session.cyr_boxes(s.client)
    check("popup: guard, no Ukrainian text in a font without Ukrainian letters", not boxes, boxes[:3])

    M.key(True)
    M.wait(HELD)
    held, held_cyr = _texts(P, i), txt(P.cyr(i))
    M.key(False)
    M.wait(0.1)
    check("popup: hold key gives OpenMap's English; the note's font kept, the buttons' back",
          held == ["Quix shared 2 map pin(s) with you:" + rest, "Add them", "Ignore"] and held_cyr == "100",
          [held, held_cyr])
    check("popup: hold key released, Ukrainian again", _texts(P, i)[1:] == ["Додати", "Ігнорувати"]
          and txt(P.cyr(i)) == "111", [_texts(P, i), txt(P.cyr(i))])

    P.hide(i)
    check("popup: hidden, its fonts back as the game had them", _fonts(P, i) == game and P.count() == 0,
          [_fonts(P, i), game])
    P.other()
    i = P.of("OTHER_ADDON_QUESTION")
    check("popup: another addon's question in the same dialog: its English and the game's fonts",
          _texts(P, i)[:2] == ["Sell everything grey?", "Okay"] and _fonts(P, i) == game,
          [_texts(P, i), _fonts(P, i)])
    P.hideAll()

    P.clear(3)
    i = P.of("OPENMAP_PINS_CLEAR")
    got = _texts(P, i)
    check("popup: delete all pins in Ukrainian", got[0] == "Видалити всі позначки (3)?" and txt(P.cyr(i))[:2] == "11",
          [got, txt(P.cyr(i))])
    P.hideAll()
    P.report()
    i = P.of("OPENMAP_REPORT_NOTE")
    got = _texts(P, i)
    check("popup: the report's text (read as OpenMap loaded) in Ukrainian",
          got[0].startswith("|cffffd100Звіт, крок 2 з 2:|r що не так?\n") and txt(P.cyr(i))[0] == "1", got)
    P.hideAll()

    key = txt(P.classicKey())
    P.classic()
    i = P.of("OPENMAP_CLASSICUI_MAP")
    got = _texts(P, i)
    check("popup: ClassicUI Forever's question in Ukrainian", key and got[0].startswith("У ClassicUI Forever")
          and txt(P.cyr(i))[0] == "1", got[:1])
    s.uadd("openmap off")
    got, fonts = _texts(P, i), _fonts(P, i)
    check("popup: /uadd openmap off, English and the game's fonts back exactly",
          got[0] == key and fonts == game and P.count() == 0, [got[0][:40], fonts, game])
    s.uadd("openmap on")
    s.pump(30)
    P.hideAll()
    P.classic()
    i = P.of("OPENMAP_CLASSICUI_MAP")
    check("popup: /uadd openmap on, Ukrainian again", _texts(P, i)[0].startswith("У ClassicUI Forever")
          and txt(P.cyr(i))[0] == "1", _texts(P, i)[:1])
    P.hideAll()
    check("popup: all hidden, nothing kept", P.count() == 0, P.count())
