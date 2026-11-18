"""The Questie options tab header checks: our Cyrillic font object on the tab name only, also on
canvases made after Questie's OnReady, and Game13Font back on "off"."""
from loader import lua_str, txt

OPTIONS_TITLE = "Загальні налаштування"         # l10n("General Options") in our Ukrainian


# The options tab header: Questie draws the tab name with Game13Font, which has no "і" in the
# client; we put our own font object on that FontString only, and Game13Font back on "off".
HEADER_FONT = "UADD_QuestieHeaderFont"
HEADER_GREY = "0.90 0.90 0.90 1.00"
BLIZZ_TAB, POPUP_TAB = "QuestieOptionsTab_Blizz_general", "QuestieOptionsTab_Popup_general"


def header(f, c, step, canvas, ours, popup=False):
    got = [txt(x) for x in c.F.header(lua_str(canvas), popup)]
    want_obj = HEADER_FONT if ours else "Game13Font"
    want_file = "FRIZQT___CYR.TTF" if ours else "FRIZQT__.TTF"
    ok = (len(got) == 4 and got[0] == want_obj and got[2] == HEADER_GREY
          and got[3].upper().endswith(want_file))
    if ours:
        ok = ok and got[1] == OPTIONS_TITLE
    where = "Questie window" if popup else "settings panel"
    return f.check(f"{step}: options header ({where}) in {want_obj}, colour kept", ok, str(got))


def late_header(f, c, step):
    """A settings canvas made after Questie's OnReady still gets our header font, found when the
    game's settings window opens or when its category is picked."""
    for how in ("panel", "select"):
        got = [txt(x) for x in c.F.lateCanvas(lua_str("uaddlate" + how), lua_str(how))]
        ok = len(got) == 2 and got[0] == HEADER_FONT and got[1].upper().endswith("FRIZQT___CYR.TTF")
        f.check(f"{step}: header of a canvas made after OnReady ({how}) in {HEADER_FONT}", ok, str(got))
