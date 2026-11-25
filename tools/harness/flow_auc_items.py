"""UADD_Auctionator: one item's name outside the results lists (Rows.lua R.Item). Run by
flow_auc_more.py while UALL Forever's item names are stubbed (selling_cancelling), set the way
Forever's Auctionator sets them (its colour; the item level inside the colour):

  * the Selling tab's item (SaleItem.lua TitleArea.Text): Ukrainian, colour kept, and the item level
    kept inside the colour;
  * a name UALL Forever does not know, or a name with letters glued on: the whole text English;
  * the buy panel's item on the Shopping tab (ItemTooltip.lua Text): the same words;
  * the Cancelling list with the item level inside the colour;
  * UALL "not now": English for now, Ukrainian once it answers;
  * Shift: exact English, Ukrainian again when it is let go; "/uadd auctionator off" (off): English.
"""
import flow_auc_craft
from loader import txt

HELD = 0.4
GREEN, PURPLE = "|cff1eff00", "|cffa335ee"
HIDE, GIRDLE = "Heavy Hide", "Revenant Girdle of Fire Protection"


def run(check, c, M, uall):
    lua = c.lua

    def eq(name, got, want):
        got = txt(got)
        check(name, got == want, f"{got!r} | want {want!r}")

    def sale():
        return M.text("text", "saleTitle")

    def buy():
        return M.text("text", "buyItem")

    check("item names: Selling item and buy panel item hooked", M.namesHooked() == 2, M.namesHooked())

    M.saleItem(HIDE, GREEN, None)
    eq("sale item: name Ukrainian, colour kept", sale(), GREEN + uall[HIDE] + "|r")
    M.saleItem(GIRDLE, PURPLE, 35)
    eq("sale item: item level inside the colour kept", sale(), PURPLE + uall[GIRDLE] + " (35)|r")
    M.saleItem("Pristine Hide", GREEN, None)
    eq("sale item: name UALL does not know stays English", sale(), GREEN + "Pristine Hide|r")
    M.saleItem("Pristine Hide", PURPLE, 35)
    eq("sale item: unknown name with item level stays English", sale(), PURPLE + "Pristine Hide (35)|r")
    M.saleItem(HIDE + " (35) x", GREEN, None)
    eq("sale item: letters after the level: whole text English", sale(), GREEN + HIDE + " (35) x|r")

    M.buyItem(GREEN + HIDE + "|r")
    eq("buy panel: item name Ukrainian, colour kept", buy(), GREEN + uall[HIDE] + "|r")
    M.buyItem(PURPLE + GIRDLE + " (35)|r")
    eq("buy panel: item level inside the colour kept", buy(), PURPLE + uall[GIRDLE] + " (35)|r")
    M.buyItem(PURPLE + GIRDLE + "|r of Doom")
    eq("buy panel: letters after the colour: whole text English", buy(), PURPLE + GIRDLE + "|r of Doom")

    M.owned(lua.table_from([lua.table_from([PURPLE + GIRDLE + " (35)|r", "1"])]))
    eq("cancelling: item level inside the colour kept", M.text("cell", "cancel", 1, 1),
       PURPLE + uall[GIRDLE] + " (35)|r")

    M.setUallWait(True)
    M.saleItem("Rugged Hide", PURPLE, None)
    eq("sale item: UALL 'not now': English for now", sale(), PURPLE + "Rugged Hide|r")
    M.setUallWait(False)
    M.wait(1.1)
    eq("sale item: UALL ready again: Ukrainian", sale(), PURPLE + uall["Rugged Hide"] + "|r")

    M.saleItem(GIRDLE, PURPLE, 35)
    M.key(True)
    M.wait(HELD)
    eq("Shift: sale item exact English", sale(), PURPLE + GIRDLE + " (35)|r")
    eq("Shift: buy panel item exact English", buy(), PURPLE + GIRDLE + "|r of Doom")
    M.key(False)
    M.wait(HELD)
    eq("Shift up: sale item Ukrainian", sale(), PURPLE + uall[GIRDLE] + " (35)|r")
    M.buyItem(GREEN + HIDE + "|r")
    M.saleItem(HIDE, GREEN, None)
    flow_auc_craft.run(check, c, M)                       # the crafting window's price text


def off(check, M):
    """'/uadd auctionator off': the Selling item and the buy panel item exact English."""
    for key in ("saleTitle", "buyItem"):
        got, want = txt(M.text("text", key)), GREEN + HIDE + "|r"
        check(f"off: {key} exact English", got == want, f"{got!r} | want {want!r}")
