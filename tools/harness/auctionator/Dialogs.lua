-- Not Auctionator: the stand-in's dialogs (part two of the stand-in, after Auctionator.lua). Each
-- part copies the real file named next to it:
--   * Auctionator.Dialogs.ShowConfirm and ShowMoney: one dialog AuctionatorDialogN per kind, made on
--     first use, then reused (hidden, its text set, shown);
--   * the commodity purchase dialogs (their texts joined by a blank line, with the red
--     "The price has increased!" prefix);
--   * the Cancelling tab's "someone has bid" money dialog and the posted chat line with a bid.
local S = AuctionatorStandIn
local FONT = S.FONT

local MORE = {
    CAREFUL_CAPS = "CAREFUL", PRICE_VARIES_WARNING = "The prices varies a lot between items.",
    UNIT_PRICE_RANGE = "Unit price: %s - %s", PRICE_INCREASED = "The price has increased!",
    ENTER_QUANTITY_TO_CONFIRM_PURCHASE = "Enter the quantity of %s to confirm purchase:",
    CONFIRM_PURCHASE_OF_X_FOR_X = "Confirm purchase of %s for %s?",
    TOTAL_OF_X_FOR_UNIT_PRICE_OF_X = "Total of %s for unit price of %s", BRACKETS_X_EACH = "(%s each)",
    BID_EXISTING_ON_OWNED_AUCTION = "Someone has bid on this auction so cancelling will cost you your deposit and:",
    BIDDING_AUCTION_INFO = "%s bidding at %s",
}
for k, v in pairs(MORE) do
    S.EN[k] = v
    _G["AUCTIONATOR_L_" .. k] = v
end

local function Red(t) return "|cffff2020" .. t .. "|r" end   -- RED_FONT_COLOR:WrapTextInColorCode

-- ── Source/Components/Dialogs.lua ──────────────────────────────────────────────────────────────
local counter = 0
local function GenerateDialog()
    counter = counter + 1
    local d = CreateFrame("Frame", "AuctionatorDialog" .. counter, UIParent)
    d:Hide()
    d.text = S.Text(d)
    return d
end

local function Buttons(d)
    d.acceptButton = CreateFrame("Button", nil, d)
    d.cancelButton = CreateFrame("Button", nil, d)
    d.acceptButton:GetFontString():SetFont(FONT, 13, "OUTLINE")
    d.cancelButton:GetFontString():SetFont(FONT, 13, "OUTLINE")
end

local confirmDialog, moneyDialog
function Auctionator.Dialogs.ShowConfirm(text, yesText, noText)
    if not confirmDialog then
        confirmDialog = GenerateDialog()
        Buttons(confirmDialog)
    end
    local d = confirmDialog
    d:Hide()
    d.text:SetText(text)
    d.acceptButton:SetText(yesText)
    d.cancelButton:SetText(noText)
    d:Show()
end

function S.DialogOf(kind) return kind == "money" and moneyDialog or confirmDialog end

function Auctionator.Dialogs.ShowMoney(text, value, acceptText, cancelText)
    if not moneyDialog then
        moneyDialog = GenerateDialog()
        Buttons(moneyDialog)
    end
    local d = moneyDialog
    d:Hide()
    d.text:SetText(text .. "\n\n" .. S.Money(value))
    d.acceptButton:SetText(acceptText)
    d.cancelButton:SetText(cancelText)
    d:Show()
end

-- Source_ModernAH/Tabs/Cancelling/Mixins/Main.lua: cancelling an auction someone has bid on.
function S.CancelWithBid(cost)
    Auctionator.Dialogs.ShowMoney(AUCTIONATOR_L_BID_EXISTING_ON_OWNED_AUCTION, cost, ACCEPT, CANCEL)
end

-- Source_ModernAH/Selling/ComposeAuctionPostedMessage.lua: one item with a bid and a buyout.
function S.PostedBid(bid, buyout)
    local A = Auctionator.Locales.Apply
    local result = A("BIDDING_AUCTION_INFO", S.LINK, S.Money(bid))
    result = A("BUYOUT_AUCTION_INFO", result, S.Money(buyout))
    Auctionator.Utilities.Message(result)
end

-- ── Source_ModernAH/Tabs/Buying/Commodity (Mixins/Dialogs.lua, Mixins/Main.lua) ─────────────────
-- The buy panel with its three dialogs; each dialog's PurchaseDetails is set, then it shows.
local buy = S.Tab("AuctionatorBuyCommodityFrame")
local function Dialog(key)
    local d = CreateFrame("Frame", nil, buy)
    d:Hide()
    d.PurchaseDetails = S.Text(d, key)
    buy[key] = d
    return d
end
Dialog("WidePriceRangeWarningDialog")
Dialog("FinalConfirmationDialog")
Dialog("QuantityCheckConfirmationDialog")

local SET = {
    WidePriceRangeWarningDialog = function(t)
        return Red(AUCTIONATOR_L_CAREFUL_CAPS) .. "\n\n" .. AUCTIONATOR_L_PRICE_VARIES_WARNING .. "\n\n" ..
            AUCTIONATOR_L_UNIT_PRICE_RANGE:format(S.Money(t.min), S.Money(t.max))
    end,
    FinalConfirmationDialog = function(t)
        return t.prefix .. AUCTIONATOR_L_CONFIRM_PURCHASE_OF_X_FOR_X:format(
            Auctionator.Utilities.CreateCountString(t.quantity), S.Money(t.total)) .. "\n\n" ..
            AUCTIONATOR_L_BRACKETS_X_EACH:format(S.Money(t.unit))
    end,
    QuantityCheckConfirmationDialog = function(t)
        return t.prefix .. AUCTIONATOR_L_TOTAL_OF_X_FOR_UNIT_PRICE_OF_X:format(S.Money(t.total), S.Money(t.unit)) ..
            "\n\n" .. AUCTIONATOR_L_ENTER_QUANTITY_TO_CONFIRM_PURCHASE:format(t.quantity)
    end,
}

-- One purchase dialog: quantity, unit price (copper); `increased`: the price went up (red prefix).
function S.Buy(key, quantity, unit, increased)
    local t = { quantity = quantity, unit = unit, total = quantity * unit, min = unit, max = unit * 7,
        prefix = increased and Red(AUCTIONATOR_L_PRICE_INCREASED .. "\n\n") or "" }
    buy:Show()
    local d = buy[key]
    d.PurchaseDetails:SetText(SET[key](t))
    d:Show()
end
function S.BuyHide(key) if key then buy[key]:Hide() else buy:Hide() end end
function S.BuyShow(key) buy[key]:Show() end

-- A buy panel made after the module's first look (Source_ModernAH/Tabs/Buying/Item): its results
-- list fills while it is not yet a window the module knows.
function S.LatePanel()
    local f = S.Tab("AuctionatorBuyItemFrame")
    S.List("late", f, { "name", "isOwned" })
    return f
end
