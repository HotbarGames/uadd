"""More UADD_Auctionator checks, run by flow_auc.py in game A (the stand-in's Dialogs.lua part):

  * the stand-in uses the installed Auctionator's English (en_drift, run first; skipped if not installed);
  * a total on sale with a pending part, and a posted chat line with a bid and a buyout;
  * Auctionator's own dialogs: Ukrainian at once when they show (also with the auction house closed),
    the money dialog's two texts joined by a blank line;
  * the commodity purchase dialogs (texts joined by a blank line, the red "price has increased" part);
  * chat: a line that is not Auctionator's is left exactly as it was;
  * the hold key let go while a purchase dialog was hidden: Ukrainian when it shows again;
  * a results list filled before its window was known: its rows in Ukrainian once it is known
    (Rows.lua asks those cells again);
  * the hold key let go in a fight: tooltip and menu back in Ukrainian when combat ends;
  * the cost of a text with a blank line that is not in the memo yet (facts);
  * what a template's %s may hold (slots): made-up English in a slot leaves the line English
    (halves_mods.auc, on every real template; its free-slot marks: tools/test_halves.py).
The expected Ukrainian is read from the module's data (flow_auc.lua), not from the module's answers.
"""
import os
import sys

import halves_mods
from loader import txt

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import make_auc_text  # noqa: E402  (tools/: reads the installed Auctionator)

HELD = 0.4
BLUE = "|cff4cb3ff"
PREFIX = BLUE + "Auctionator: |r"
RED = "|cffff2020"
MISSES = 200


def en_drift(check, M):
    """The stand-in must use the real words: each of its texts as the installed Auctionator's
    Locales/enUS.lua has it (read at test time; the repo keeps no copy)."""
    addon = make_auc_text.addon_dir()
    if not (addon / "Locales" / "enUS.lua").is_file():
        check("stand-in uses Auctionator's English", True, "skipped: Auctionator not installed")
        return
    real, _ = make_auc_text.read_enus(addon)
    bad = sorted(k for k, v in M.standInEN().items() if k not in real or real[k][0] != txt(v))
    check("stand-in uses Auctionator's English", not bad, ", ".join(bad))


def run(check, c, M, u, uo, facts):
    def eq(name, got, want):
        got = txt(got)
        check(name, got == want, f"{got!r} | want {want!r}")

    def m(copper):
        return txt(M.money(copper))
    link = txt(M.link())

    # Two of Auctionator's texts joined into one line.
    M.total(1234500, 9900)
    eq("template: total on sale with pending", M.text("text", "total"),
       uo("Total on sale: %s (%s pending)") % (m(1234500), m(9900)))
    M.postedBid(1000, 2500)
    eq("chat: posted with a bid and a buyout", M.chat(),
       PREFIX + u("BUYOUT_AUCTION_INFO") % (u("BIDDING_AUCTION_INFO") % (link, m(1000)), m(2500)))

    # Chat: other lines untouched.
    M.printOther("Search")
    eq("chat: a line that is not Auctionator's untouched", M.chat(), "Search")
    M.printOther("Auctionator: ", "Search")
    eq("chat: a print of two values untouched", M.chat(), "Auctionator:  Search")

    # Its own dialogs: Ukrainian at once, the auction house closed.
    check("dialogs: Auctionator.Dialogs.Show* hooked", M.dialogHooks(), "")
    M.ah(False)
    # A window shown before the module knows it: its rows are filled outside. The money dialog's
    # first show makes the module look for windows again (no walk over the late one): the next
    # fill of those rows is in Ukrainian.
    M.latePanel()
    M.lateShow()
    M.lateResults(4)
    eq("late window, not known yet: row cell English", M.text("cell", "late", 2, 2), "Yes")
    name = txt(M.cancelWithBid(54321))
    M.lateResults(4)
    eq("late window, known now: row cell Ukrainian", M.text("cell", "late", 2, 2), u("UNDERCUT_YES"))
    n = int(name.replace("AuctionatorDialog", ""))
    eq("money dialog (AH closed): Ukrainian at once", M.text("dialog", n, "text"),
       u("BID_EXISTING_ON_OWNED_AUCTION") + "\n\n" + m(54321))
    M.dialogHide(n)
    M.cancelWithBid(777)
    eq("money dialog shown again: Ukrainian at once", M.text("dialog", n, "text"),
       u("BID_EXISTING_ON_OWNED_AUCTION") + "\n\n" + m(777))
    M.dialogHide(n)
    M.ah(True)
    M.wait(1.0)

    # The commodity purchase dialogs.
    M.buy("WidePriceRangeWarningDialog", 5, 2500, False)
    eq("purchase: wide price range", M.text("text", "WidePriceRangeWarningDialog"),
       RED + u("CAREFUL_CAPS") + "|r\n\n" + u("PRICE_VARIES_WARNING") + "\n\n" + u("UNIT_PRICE_RANGE") % (m(2500), m(17500)))
    up = RED + u("PRICE_INCREASED") + "\n\n|r"
    count = BLUE + " x5|r"
    M.buy("FinalConfirmationDialog", 5, 2500, True)
    eq("purchase confirm, price increased", M.text("text", "FinalConfirmationDialog"),
       up + u("CONFIRM_PURCHASE_OF_X_FOR_X") % (count, m(12500)) + "\n\n" + u("BRACKETS_X_EACH") % m(2500))
    M.buy("QuantityCheckConfirmationDialog", 5, 2500, True)
    eq("purchase quantity check, price increased", M.text("text", "QuantityCheckConfirmationDialog"),
       up + u("TOTAL_OF_X_FOR_UNIT_PRICE_OF_X") % (m(12500), m(2500)) + "\n\n" +
       u("ENTER_QUANTITY_TO_CONFIRM_PURCHASE") % "5")
    M.buy("FinalConfirmationDialog", 5, 2500, False)
    confirm = u("CONFIRM_PURCHASE_OF_X_FOR_X") % (count, m(12500)) + "\n\n" + u("BRACKETS_X_EACH") % m(2500)
    eq("purchase confirm", M.text("text", "FinalConfirmationDialog"), confirm)

    # The hold key let go while the dialog is hidden: Ukrainian when it shows (its window stays shown).
    M.key(True)
    M.wait(HELD)
    eq("Shift: purchase confirm exact English", M.text("text", "FinalConfirmationDialog"),
       f"Confirm purchase of {count} for {m(12500)}?\n\n({m(2500)} each)")
    M.buyHide("FinalConfirmationDialog")
    M.key(False)
    M.wait(0.1)
    M.buyShow("FinalConfirmationDialog")
    eq("Shift let go while hidden: Ukrainian when shown", M.text("text", "FinalConfirmationDialog"), confirm)
    M.buyHide(None)

    # The hold key held when a fight starts: the core gives the Ukrainian back at once, but the module
    # waits for the end of combat. The key is let go in the fight, so the core says nothing more:
    # the end of combat alone must bring the tooltip and the menu back to Ukrainian.
    M.tooltip(3)
    M.columnMenu()
    M.key(True)
    M.wait(HELD)
    eq("Shift: tooltip exact English", M.text("tip", 4, "Right"), "|cffffffff3 days|r")
    M.combat(True)
    M.key(False)
    M.wait(0.1)
    eq("Shift let go in combat: tooltip waits (English)", M.text("tip", 4, "Right"), "|cffffffff3 days|r")
    M.combat(False)
    eq("after combat: tooltip Ukrainian", M.text("tip", 4, "Right"), "|cffffffff" + u("X_DAYS") % "3" + "|r")
    eq("after combat: menu Ukrainian", M.text("menu", 1), uo("Name"))
    M.menuHide()
    M.tooltipHide()

    # Cost of a memo miss.
    memo0 = M.memo()
    facts["nl_miss_ms_uk"] = round(M.missCost(MISSES, "uk"), 4)
    facts["nl_miss_ms_en"] = round(M.missCost(MISSES, "en"), 4)
    facts["line_miss_ms_en"] = round(M.missCost(MISSES, "line"), 4)
    check("blank-line texts kept in the memo (found or not)", M.memo() - memo0 >= 2 * MISSES, f"{memo0} -> {M.memo()}")
    slots(check, c, M, u)


def slots(check, c, M, u):
    """What a template's %s may hold (Words.lua Slot): a value, one of Auctionator's texts, or a slot
    that takes any text. Made-up English anywhere else leaves the whole line English (never half).
    Made-up English for some keys and a made-up ui/text.lua are put in for a while, then taken out."""
    W, lua = c.H.ns.UADD_Auctionator.Words, c.lua.globals()
    en = {k: txt(v) for k, v in M.standInEN().items()}
    link, junk = txt(M.link()), "Florp the wobbly gizmo"

    def m(copper):
        return txt(M.money(copper))

    def eq(name, got, want):
        got = txt(got) if got is not None else None
        check(name, got == want, f"{got!r} | want {want!r}")
    halves_mods.auc(check, c)       # made-up English in each slot of every real template
    eq("slot: link and money kept", W.Text(en["BUYOUT_AUCTION_INFO"] % (link, m(2500))),
       u("BUYOUT_AUCTION_INFO") % (link, m(2500)))
    # Made-up English for keys the stand-in does not have: free slots, a link with a space before a %s.
    made = {"X_PRICE_HISTORY": "%s blorp chart", "DELETE_LIST_CONFIRM": "Zap '%s' for good?",
            "MULTIPLE_STACKS_AUCTION_INFO": "%s %s, zumming %s", "X_STACKS_OF_X": "%s blorps of %s"}
    for k, v in made.items():
        lua["AUCTIONATOR_L_" + k] = v
    W.Build()
    eq("slot: free (item name) kept", W.Text("Wobble Gizmo blorp chart"), u("X_PRICE_HISTORY") % "Wobble Gizmo")
    eq("slot: free (list name) kept", W.Text("Zap 'Wobble List' for good?"), u("DELETE_LIST_CONFIRM") % "Wobble List")
    eq("slot: a link's name with a space is not cut", W.Text(f"{link} 3 blorps of 20, zumming {m(900)}"),
       u("MULTIPLE_STACKS_AUCTION_INFO") % (link, u("X_STACKS_OF_X") % ("3", "20"), m(900)))
    eq("slot: made-up English in a non-free slot of it", W.Text(f"{link} {junk}, zumming {m(900)}"), None)
    for k in made:
        lua["AUCTIONATOR_L_" + k] = None
    # ui/text.lua's word (one lowercase word) and free slots, on made-up code texts.
    ns, real = c.H.ns.UADD_Auctionator, c.H.ns.UADD_Auctionator.UA_TEXT
    src = hashtext.write_lua({}, [hashtext.template("Blorf set %s: %s", "Блорф %s: %s", word=[1], free=[2]),
                                  hashtext.template("Unknown blorf: %s", "Невідомий блорф: %s", word=[1])], "UA_TEXT")
    lua.loadstring(src.encode("utf-8"))(None, ns)       # the harness Lua takes bytes for UTF-8
    W.Build()
    eq("code slot: word and free kept", W.Text("Blorf set auto_zap: Big Value"), "Блорф auto_zap: Big Value")
    eq("code slot: a word slot with two words stays English", W.Text("Blorf set Auto Zap: 5"), None)
    eq("code slot: word kept", W.Text("Unknown blorf: zap_it"), "Невідомий блорф: zap_it")
    eq("code slot: made-up English stays English", W.Text("Unknown blorf: " + junk), None)
    ns.UA_TEXT = real
    W.Build()
