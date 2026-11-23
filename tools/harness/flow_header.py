"""The Questie options tab header checks: our Cyrillic font object on the tab name only, also on
canvases made after Questie's OnReady, and Game13Font back on "off"."""
from loader import lua_str, txt

OPTIONS_TITLE = "Загальні налаштування"         # l10n("General Options") in our Ukrainian


# The options tab header: Questie draws the tab name with Game13Font, which has no "і" in the
# client; we put our own font object on that FontString only, and Game13Font back on "off".
HEADER_FONT = "UADD_QuestieHeaderFont"
HEADER_GREY = "0.90 0.90 0.90 1.00"
BLIZZ_TAB, POPUP_TAB = "QuestieOptionsTab_Blizz_general", "QuestieOptionsTab_Popup_general"


# Off: the header that still shows Ukrainian (Questie keeps its language until a reload) is set to English, as Questie
# draws it after the reload. Returns its font object's name and file then.
ENGLISH_LUA = r"""
return function(name, title)
    local canvas = rawget(_G, name)
    local regions = { canvas:GetRegions() }
    if canvas.content then
        for _, r in ipairs({ canvas.content:GetRegions() }) do regions[#regions + 1] = r end
    end
    for _, r in ipairs(regions) do
        if r:GetObjectType() == "FontString" and r:GetText() == title then
            r:SetText("General Options")
            local o = r:GetFontObject()
            return o and o:GetName() or "none", (r:GetFont())
        end
    end
    return "no header", ""
end
"""


def header(f, c, step, canvas, ours, popup=False):
    got = [txt(x) for x in c.F.header(lua_str(canvas), popup)]
    # The font follows the text: off, a header still Ukrainian keeps ours (Game13Font there is a box).
    cyr = ours or (len(got) == 4 and got[1] == OPTIONS_TITLE)
    want_obj = HEADER_FONT if cyr else "Game13Font"
    want_file = "FRIZQT___CYR.TTF" if cyr else "FRIZQT__.TTF"
    ok = (len(got) == 4 and got[0] == want_obj and got[2] == HEADER_GREY
          and got[3].upper().endswith(want_file))
    if ours:
        ok = ok and got[1] == OPTIONS_TITLE
    where = "Questie window" if popup else "settings panel"
    shows = "Ukrainian" if cyr else "English"
    out = f.check(f"{step}: options header ({where}) shows {shows} in {want_obj}, colour kept", ok, str(got))
    if cyr and not ours:
        eng = [txt(x) for x in c.lua.execute(ENGLISH_LUA)(lua_str(canvas), lua_str(OPTIONS_TITLE))]
        f.check(f"{step}: options header ({where}) set English gets Game13Font back",
                len(eng) == 2 and eng[0] == "Game13Font" and eng[1].upper().endswith("FRIZQT__.TTF"), str(eng))
    return out


def late_header(f, c, step):
    """A settings canvas made after Questie's OnReady still gets our header font, found when the
    game's settings window opens or when its category is picked."""
    for how in ("panel", "select"):
        got = [txt(x) for x in c.F.lateCanvas(lua_str("uaddlate" + how), lua_str(how))]
        ok = len(got) == 2 and got[0] == HEADER_FONT and got[1].upper().endswith("FRIZQT___CYR.TTF")
        f.check(f"{step}: header of a canvas made after OnReady ({how}) in {HEADER_FONT}", ok, str(got))
