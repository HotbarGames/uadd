"""Part of flow_fxpb.py (game A): texts ForeverXP Bar builds from numbers and joins from pieces.

  * Times (UADD_ForeverXPBar/Time.lua): inside a template the units stand apart ("4 год 03 хв");
    a text that is only the time, such as a camp icon's countdown, is short ("36хв"); an XP amount
    such as "1.25m" is not a time.
  * The line under the bar's right side: "Completed: 15.3%" and "Rested: 3.7%", each alone and
    joined by a white bullet, colours kept.
  * A text glued from known pieces (Words.lua Parts): a level-up card's footer; a time as a piece
    has its units apart; one unknown piece keeps the whole text English (never a mixed line).
"""
from loader import lua_str, txt

BULLET = "•"
DONE_EN, REST_EN = "|cffffbd47Completed: 15.3%|r", "|cFF66B2FFRested: 3.7%|r"
DONE_UK, REST_UK = "|cffffbd47Виконано: 15.3%|r", "|cFF66B2FFВідпочинок: 3.7%|r"
BOTH_EN = DONE_EN + " |cFFFFFFFF" + BULLET + "|r " + REST_EN
BOTH_UK = DONE_UK + " |cFFFFFFFF—|r " + REST_UK
CAMP_EN, CAMP_UK = "36m", "36хв"

IN_TEMPLATE = (("4h 03m", "4 год 03 хв"), ("2d 5h", "2 д 5 год"), ("5m", "5 хв"), ("<1m", "<1 хв"),
               (">99d", ">99 д"), ("5m03s", "5 хв 03 с"), ("1h05", "1 год 05"), ("1.5 h", "1.5 год"),
               ("Fri 22:30", "пт 22:30"))
# Alone: the camp icon's "1h05" as a clock; a card box's "1h12m" and "2d 5h" with no spaces.
ALONE = (("36m", "36хв"), ("45s", "45с"), ("1h05", "1:05"), ("1h12m", "1год12хв"), ("5m03s", "5хв03с"),
         ("2d 5h", "2д5год"), ("~4h 03m", "~4 год 03 хв"), ("12%  (5m03s)", "12%  (5 хв 03 с)"))


def checks(check, eq, M, S, cyr):
    """eq: flow_fxpb._eq. S: the seed, English -> Ukrainian. cyr: UADD.IsCyrFont. Leaves the Completed/Rested line joined
    and the camp countdown on screen, for the hold key and "off" checks after it."""
    for en, uk in IN_TEMPLATE:
        eq(check, f"time in a template: {en}", M.uk(lua_str("Time this level: " + en)), S["Time this level: %s"] % uk)
    for en, uk in ALONE:
        eq(check, f"time alone: {en}", M.uk(lua_str(en)), uk)
    check("not a time: an XP amount ('1.25m', '125.0K') left alone", M.uk("1.25m") is None and M.uk("125.0K") is None,
          f"{M.uk('1.25m')!r} {M.uk('125.0K')!r}")
    eq(check, "Completed part alone", M.uk(lua_str(DONE_EN)), DONE_UK)
    eq(check, "Rested part alone", M.uk(lua_str(REST_EN)), REST_UK)
    eq(check, "Completed and Rested joined", M.uk(lua_str(BOTH_EN)), BOTH_UK)
    for done, rest, want, name in ((15.3, None, DONE_UK, "Completed alone"), (None, 3.7, REST_UK, "Rested alone"),
                                   (15.3, 3.7, BOTH_UK, "Completed and Rested joined")):
        M.under(done, rest)
        eq(check, f"on screen: {name}", M.text("underRight"), want)
    M.camp(CAMP_EN)
    eq(check, "on screen: camp icon countdown", M.text("camp"), CAMP_UK)
    check("on screen: their own Latin font swapped for a Cyrillic one",
          cyr(M.font("underRight")[0]) and cyr(M.font("camp")[0]), f"{M.font('underRight')} {M.font('camp')}")
    # Gold Farm bar, bottom right: the price-source line glued with a count tail.
    c = "|cff9aa3b5"
    for en, uk in ((c + "Auction prices (12 AH)|r", c + "Ціни з аукціону (12)|r"),
                   (c + "Auction prices (12 AH, 3 vendor fallback)|r", c + "Ціни з аукціону (12, 3 торг.)|r"),
                   (c + "Vendor prices|r", c + "Ціни торговця|r")):
        eq(check, f"gold farm line: {en[10:20]}...", M.uk(lua_str(en)), uk)
    check("gold farm line with an unknown piece stays English", M.uk(lua_str(c + "Auction prices (12 AH, x vendor fallback wobbly)|r")) is None)
    footer = "1 death  " + BULLET + "  12 kills  " + BULLET + "  3 quests"
    eq(check, "glued card footer", M.uk(lua_str(footer)), "1 смерть  —  вбивств: 12  —  завдань: 3")
    eq(check, "a time as a piece: units apart", M.uk(lua_str("Lock Bar - 5m")), S["Lock Bar"] + " — 5 хв")
    check("one known piece, one unknown: stays English (no mixed line)", M.uk("Lock Bar - world") is None,
          txt(M.uk("Lock Bar - world") or ""))
