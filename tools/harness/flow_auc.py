"""UADD_Auctionator on a stand-in for Auctionator (tools/harness/auctionator: its AUCTIONATOR_L_* texts,
its four tab frames by name, texts given when a frame is made, a KeyValue label set in OnLoad, results
lists whose rows are made when first needed, column headers, chat lines with its prefix, "/atr help",
its own dialog AuctionatorDialogN, a StaticPopup question, tooltip price lines and a column menu).
The expected Ukrainian is read from the module's data (flow_auc.lua), not from the module's answers.
Run by run.py after the other flows.

  * Game A (stand-in, UADD, the module; English client): each kind of text in Ukrainian with a
    Cyrillic font; a header and result rows made after the last look in Ukrainian on their first
    draw; dates ("Вівторок, 25 лютого"); the search box, the export list and the AUCTIONATOR_L_*
    globals stay English; templates (total on sale, the posted chat line); item names untouched;
    the dialog, popup, tooltip and menu; the hold key; combat (tooltip lines without a search);
    the cost of a burst of row redraws; "/uadd auctionator off" (exact English and fonts, the
    game's print handler back) and on. Purchase dialogs, joined texts and more: flow_auc_more.py.
  * Game B: a German client (the module does nothing).
  * Game C: no Auctionator (the module waits).
"""
import collections
import gc
import os
import sys

import flow_auc_head
import flow_auc_more
import session
from loader import Addon, Client, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
STAND_IN = Addon("Auctionator", os.path.join(HERE, "auctionator"), session.FLAVOR)
MODULE = "UADD_Auctionator"
HELD = 0.4              # the hold key counts after 0.25 s
ROWS, PASSES = 40, 50   # the redraw burst
ROW_BUDGET_MS = 0.25    # per row redraw with the module on, in the harness's Lua
FONT = ("Interface\\AddOns\\Auctionator\\Fonts\\StandIn.ttf", 13, "OUTLINE")
BLUE = "|cff4cb3ff"
PREFIX = BLUE + "Auctionator: |r"


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def _addon(name):
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


def _game(addons, locale="enUS"):
    c = Client(addons, None, locale)
    for f in ("flow_auc.lua", "flow_auc_sell.lua"):
        c.lua.execute(read_text(os.path.join(HERE, f)))
    c.start()
    c.H.pump(60)
    return c, c.H.auc


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def _eq(check, name, got, want):
    got = txt(got)
    check(name, got == want, f"{got!r} | want {want!r}")


def _m(M, copper):
    return txt(M.money(copper))


def _font(M, *where):
    p, size, flags = M.font(*where)
    return txt(p), size, txt(flags)


def surfaces(check, M, Cyr, u, uo):
    """Texts on the open auction house, rows and headers made later, dates, what stays English."""
    for key, en in (("searchButton", "Search"), ("skipLabel", "Skip"), ("exportTitle", "Search"),
                    ("shopStatus", "Fetching item info...")):
        _eq(check, f"{key} ({en}) in Ukrainian", M.text("text", key), uo(en))
        check(f"{key}: Cyrillic font, size kept", Cyr(M.font("text", key)[0]) and M.font("text", key)[1] == 13,
              M.font("text", key))
    flow_auc_head.surfaces(check, M, u, uo)
    made = M.rowsMade("shop")
    M.results(4)                                    # four new rows: no step
    check("rows made now (lazily)", M.rowsMade("shop") == made + 4, f"{made} -> {M.rowsMade('shop')}")
    _eq(check, "new row: 'Yes' in Ukrainian on its first draw", M.text("cell", "shop", 2, 2), u("UNDERCUT_YES"))
    check("new row: Cyrillic font on its first draw", Cyr(M.font("cell", "shop", 2, 2)[0]), M.font("cell", "shop", 2, 2))
    _eq(check, "new row: item name untouched", M.text("cell", "shop", 1, 1), "Linen Cloth")
    check("new row: item name keeps its own font", _font(M, "cell", "shop", 1, 1) == FONT, M.font("cell", "shop", 1, 1))
    M.results(0)
    _eq(check, "no results: SetText(AUCTIONATOR_L_NO_RESULTS) in Ukrainian", M.text("text", "shopStatus"), u("NO_RESULTS"))
    M.results(4)
    M.history()
    _eq(check, "date: 'Tuesday, February 25' -> 'Вівторок, 25 лютого'", M.text("cell", "history", 1, 1), "Вівторок, 25 лютого")
    _eq(check, "date: today", M.text("cell", "history", 2, 1), u("TODAY"))
    box, export = M.readBack()
    check("search box keeps EXTENDED_SEARCH_ACTIVE_TEXT (read back)", box, "")
    check("export list check box stays English (read back)", export, M.text("text", "exportCheck"))
    check("EXTENDED_SEARCH_ACTIVE_TEXT never translated", M.uk("%extended search active%") is None, "")
    check("AUCTIONATOR_L_* globals unchanged", M.globalsSame(), "")
    M.total(1234500, 0)
    _eq(check, "template: total on sale", M.text("text", "total"), u("TOTAL_ON_SALE") % _m(M, 1234500))


def chat_dialogs_tips(check, c, M, Cyr, u, uo):
    link, cnt = txt(M.link()), BLUE + " x5|r"
    M.posted(5, 2500)
    _eq(check, "chat: posted (STACK_AUCTION_INFO), link kept", M.chat(),
        PREFIX + u("STACK_AUCTION_INFO") % (link + cnt, _m(M, 12500), _m(M, 2500)))
    M.posted(1, 2500)
    _eq(check, "chat: posted (BUYOUT_AUCTION_INFO)", M.chat(), PREFIX + u("BUYOUT_AUCTION_INFO") % (link, _m(M, 2500)))
    M.help()
    _eq(check, "chat: /atr help line", M.chat(), PREFIX + "h, help: " + uo("Show this help message."))
    _eq(check, "chat: /atr help line 1", M.chat(2), PREFIX + "rt, resettimer: " + uo("Reset full scan timer."))
    name = txt(M.dialog())
    n = int(name.replace("AuctionatorDialog", ""))
    _eq(check, "own dialog made later: Ukrainian at once", M.text("dialog", n, "text"), u("CONFIRM_UNHIDE_ALL"))
    check("own dialog: Cyrillic font", Cyr(M.font("dialog", n, "text")[0]), M.font("dialog", n, "text"))
    gl = c.lua.globals().UADD.Glossary.Text
    ours = txt(gl("ui.accept")) + "|" + txt(gl("ui.cancel"))   # the globals are English: ours (flow_auc_popup.py)
    _eq(check, "own dialog: the game's ACCEPT / CANCEL ours", M.text("dialog", n, "acceptButton") + "|" + M.text("dialog", n, "cancelButton"),
        ours)
    M.dialogHide(n)
    M.confirmPost()
    _eq(check, "popup: question, link kept", M.text("popup", "text"), u("CONFIRM_POST_LOW_PRICE") % link)
    check("popup: Cyrillic font", Cyr(M.font("popup", "text")[0]), M.font("popup", "text"))
    _eq(check, "popup: the game's buttons ours", M.text("popup", "button1") + "|" + M.text("popup", "button2"), ours)
    M.tooltip(3)
    _eq(check, "tooltip: item name untouched", M.text("tip", 1), "Linen Cloth")
    _eq(check, "tooltip: Vendor + count", M.text("tip", 2), u("VENDOR") + cnt)
    _eq(check, "tooltip: Auction + count", M.text("tip", 3), u("AUCTION") + cnt)
    _eq(check, "tooltip: unknown", M.text("tip", 3, "Right"), "|cffffffff" + u("UNKNOWN") + "  |r")
    _eq(check, "tooltip: Auction Age", M.text("tip", 4), u("AUCTION_AGE"))
    _eq(check, "tooltip: X days", M.text("tip", 4, "Right"), "|cffffffff" + u("X_DAYS") % "3" + "|r")
    _eq(check, "tooltip: Disenchant", M.text("tip", 5), u("DISENCHANT"))
    _eq(check, "tooltip: total items", M.text("tip", 6), u("TOTAL_ITEMS_COLORED") % "7")
    _eq(check, "tooltip: another addon's line untouched", M.text("tip", 7), "Vendor Price")
    check("tooltip: Cyrillic font on our lines", Cyr(M.font("tip", 2)[0]), M.font("tip", 2))
    M.columnMenu()
    _eq(check, "column menu in Ukrainian", M.text("menu", 1) + "|" + M.text("menu", 2), uo("Name") + "|" + uo("Price"))
    M.menuHide()
    _eq(check, "column menu hidden: English back", M.text("menu", 1) + "|" + M.text("menu", 2), "Name|Price")
    M.columnMenu()


def hold_key(check, M, u, uo):
    M.key(True)
    M.wait(HELD)
    _eq(check, "Shift: button exact English", M.text("text", "searchButton"), "Search")
    check("Shift: its own font back", _font(M, "text", "searchButton") == FONT, M.font("text", "searchButton"))
    _eq(check, "Shift: row cell exact English", M.text("cell", "shop", 2, 2), "Yes")
    flow_auc_head.held(check, M)
    _eq(check, "Shift: date exact English", M.text("cell", "history", 1, 1), "Tuesday, February 25")
    _eq(check, "Shift: tooltip exact English", M.text("tip", 4, "Right"), "|cffffffff3 days|r")
    _eq(check, "Shift: popup exact English", M.text("popup", "text"), "The price of " + txt(M.link()) +
        " looks a bit low. Are you sure you want to post at that price?")
    _eq(check, "Shift: menu exact English", M.text("menu", 1), "Name")
    M.key(False)
    M.wait(0.1)
    _eq(check, "Shift up: button Ukrainian", M.text("text", "searchButton"), uo("Search"))
    _eq(check, "Shift up: row cell Ukrainian", M.text("cell", "shop", 2, 2), u("UNDERCUT_YES"))
    _eq(check, "Shift up: date Ukrainian", M.text("cell", "history", 1, 1), "Вівторок, 25 лютого")
    _eq(check, "Shift up: tooltip Ukrainian", M.text("tip", 4, "Right"), "|cffffffff" + u("X_DAYS") % "3" + "|r")
    _eq(check, "Shift up: popup Ukrainian", M.text("popup", "text"), u("CONFIRM_POST_LOW_PRICE") % txt(M.link()))
    _eq(check, "Shift up: menu Ukrainian", M.text("menu", 1), uo("Name"))
    M.menuHide()
    M.popupHide()


def game_a(check, facts):
    c, M = _game([STAND_IN, _addon("UADD"), _addon(MODULE)])
    Cyr = c.lua.globals().UADD.IsCyrFont

    def u(key):
        v = M.ua(key)
        return txt(v) if v is not None else f"<no Ukrainian for {key}>"

    def uo(en):
        v = M.ukOf(en)
        return txt(v) if v is not None else f"<no Ukrainian for {en!r}>"
    flow_auc_more.en_drift(check, M)
    M.ah(True)
    M.wait(1.0)
    surfaces(check, M, Cyr, u, uo)
    chat_dialogs_tips(check, c, M, Cyr, u, uo)
    hold_key(check, M, u, uo)
    flow_auc_more.run(check, c, M, u, uo, facts)
    # Combat: tooltip lines through the cheap path (no search), known cells stay Ukrainian.
    M.combat(True)
    memo0 = M.memo()
    M.tooltip(9)
    _eq(check, "combat: tooltip new days number Ukrainian", M.text("tip", 4, "Right"), "|cffffffff" + u("X_DAYS") % "9" + "|r")
    _eq(check, "combat: tooltip label Ukrainian", M.text("tip", 2), u("VENDOR") + BLUE + " x5|r")
    M.results(4)
    _eq(check, "combat: known cell stays Ukrainian", M.text("cell", "shop", 2, 2), u("UNDERCUT_YES"))
    check("combat: no search (memo unchanged)", M.memo() == memo0, f"{memo0} -> {M.memo()}")
    M.tooltipHide()
    # Combat, and the client marks the tooltip lines secret (reading them throws): no UADD error,
    # the lines stay exactly as the game gave them, and the next plain tooltip is Ukrainian again.
    M.clearError()
    M.secretTips(True)
    try:
        M.tooltip(8)
    finally:
        M.secretTips(False)
    err = M.lastError()
    check("secret tooltip lines: no UADD error", err is None, txt(err) if err is not None else "")
    got = txt(M.text("tip", 4, "Right"))
    check("secret tooltip lines: left as the game gave them", got == "|cffffffff8 days|r", repr(got))
    M.tooltip(7)
    _eq(check, "after secret lines: tooltip Ukrainian again", M.text("tip", 4, "Right"), "|cffffffff" + u("X_DAYS") % "7" + "|r")
    M.combat(False)
    M.tooltipHide()
    # Cost: a burst of row redraws.
    ms, calls, sets = M.burst(ROWS, PASSES)
    per = ms / (ROWS * PASSES)
    check("burst: one hook call per cell SetText", calls == sets and sets > 0, f"{calls} for {sets}")
    check(f"burst: under {ROW_BUDGET_MS} ms per row redraw", per < ROW_BUDGET_MS, f"{per:.4f} ms")
    facts["row_ms_on"] = round(per, 4)
    facts["rows_hooked"] = list(M.rows())
    owned = (-PASSES) % 3 or 3                      # a row the last pass marked "Yes"
    _eq(check, "after burst: 'Yes' cell Ukrainian", M.text("cell", "shop", owned, 2), u("UNDERCUT_YES"))
    # Off: exact English and fonts; on again.
    M.uadd("auctionator off")
    for where, en in ((("text", "searchButton"), "Search"), (("text", "skipLabel"), "Skip"),
                      (("header", "price"), "Price"), (("header", "name"), "Name"),
                      (("cell", "history", 1, 1), "Tuesday, February 25"), (("text", "shopStatus"), "No results found.")):
        _eq(check, f"off: {where[1]} exact English", M.text(*where), en)
        check(f"off: {where[1]} exact font", _font(M, *where) == FONT, M.font(*where))
    flow_auc_more.selling_off(check, M)
    M.results(4)
    _eq(check, "off: new draw stays English", M.text("cell", "shop", 2, 2), "Yes")
    check("off: no font of ours left", M.fontCount() == 0, M.fontCount())
    check("off: the game's print handler back, no chat frame field", M.chatPutBack(), "")
    M.posted(1, 2500)
    _eq(check, "off: chat line exact English", M.chat(), PREFIX + "%s buyout at %s" % (txt(M.link()), _m(M, 2500)))
    ms_off, _, _ = M.burst(ROWS, PASSES)
    facts["row_ms_off"] = round(ms_off / (ROWS * PASSES), 4)
    M.uadd("auctionator on")
    M.results(4)
    _eq(check, "on again: row cell Ukrainian", M.text("cell", "shop", 2, 2), u("UNDERCUT_YES"))
    _eq(check, "on again: button Ukrainian", M.text("text", "searchButton"), uo("Search"))
    check("guard (no Ukrainian in a font without Ukrainian letters)", not session.cyr_boxes(c), session.cyr_boxes(c)[:3])
    _errors(c, check, "game A")


def game_b(check):
    c, M = _game([STAND_IN, _addon("UADD"), _addon(MODULE)], "deDE")
    M.ah(True)
    M.wait(1.0)
    M.results(4)
    M.tooltip(3)
    check("deDE: cell Populate not hooked", M.populateSame(), "")
    check("deDE: chat not wrapped", not M.chatActive() and M.chatPutBack(), "")
    _eq(check, "deDE: button English", M.text("text", "searchButton"), "Search")
    _eq(check, "deDE: row cell English", M.text("cell", "shop", 2, 2), "Yes")
    _eq(check, "deDE: tooltip English", M.text("tip", 2), "Vendor" + BLUE + " x5|r")
    check("deDE: nothing changed", M.textCount() == 0 and tuple(M.rows()) == (0, 0), f"{M.textCount()} {tuple(M.rows())}")
    _errors(c, check, "game B (deDE)")


def game_c(check):
    c, M = _game([_addon("UADD"), _addon(MODULE)])
    M.uadd("auctionator")
    _errors(c, check, "game C (no Auctionator)")
    said = " ".join(txt(x) for x in list(c.H.chat.values())[-3:])
    check("game C: module waits", "Auctionator не завантажено" in said, said[:160])


def run(check, facts):
    if not module_there():
        check("UADD_Auctionator is there", False, "no UADD_Auctionator/UADD_Auctionator.toc")
        return
    for g in (lambda: game_a(check, facts), lambda: game_b(check), lambda: game_c(check)):
        g()
        gc.collect()


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("auc: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_auc.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
