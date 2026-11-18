-- Not Auctionator: the stand-in's Selling tab (part three of the stand-in, after Dialogs.lua),
-- Source_LegacyAH/Tabs/Selling as Forever has it:
--   * a number box whose Label sits inside its edit box (set in OnLoad from a KeyValue);
--   * two history tables in a hidden panel, their headers named at load;
--   * bag groups named with the game's item class names (and Auctionator's own Favourites).
local S = AuctionatorStandIn
local FONT = S.FONT
local Text, Tab, List = S.Text, S.Tab, S.List

local MORE = { QUANTITY = "Quantity", FAVOURITES = "Favourites", UNIT_PRICE = "Unit Price", DATE = "Date" }
for k, v in pairs(MORE) do
    S.EN[k] = v
    _G["AUCTIONATOR_L_" .. k] = v
end

local sell = Tab("AuctionatorSellingFrame")
table.insert(S.tabs, sell)
-- A number box (NumericInputBoxAlternate.xml): its Label lives inside the edit box, set in OnLoad.
local qty = CreateFrame("Frame", nil, sell)
qty.labelText = AUCTIONATOR_L_QUANTITY                             -- KeyValue
qty.InputBox = CreateFrame("EditBox", nil, qty)
qty.InputBox.Label = Text(qty.InputBox, "quantityLabel")
qty.InputBox.Label:SetText(qty.labelText)
qty.InputBox:SetText("1")
S.quantityBox = qty.InputBox

-- Two history tables in a panel that is hidden until the History button: their headers are named
-- when the tables are built, at load (Buying/Mixins/HistoryPrices.lua, ResultsListing:Init).
local prices = CreateFrame("Frame", nil, sell)
prices:Hide()
local realm = List("realm", prices, { "price", "date" })
S.Header(realm.HeaderContainer, "realmPrice", AUCTIONATOR_L_UNIT_PRICE)
S.Header(realm.HeaderContainer, "realmDate", AUCTIONATOR_L_DATE)
function S.ToggleHistory(on) prices:SetShown(on) end

-- The bag view's groups (Selling/Mixins/BagGroup*.lua): pooled frames named with SetName; the
-- title is a button (its SetText is not the FontString's).
AuctionatorGroupsViewGroupMixin = {}
function AuctionatorGroupsViewGroupMixin:SetName(name, isCustom)
    self.name = name
    self.isCustom = isCustom
    self.GroupTitle:SetText(_G["AUCTIONATOR_L_" .. name] or name)
end
local bag = CreateFrame("Frame", nil, sell)
local groups = {}
S.groups = groups
local CLASSES = { "Weapon", "Armor", "Container", "Consumable", "Tradegoods", "Projectile", "Quiver", "Recipe",
    "Reagent", "Miscellaneous", "Questitem", "Key" }
-- The groups made now (from the pool): Favourites first, then one per item class (the game's names).
function S.BagView()
    local names = { { "FAVOURITES", true } }
    for _, k in ipairs(CLASSES) do names[#names + 1] = { C_Item.GetItemClassInfo(Enum.ItemClass[k]), false } end
    for i, n in ipairs(names) do
        local g = groups[i]
        if not g then
            g = Mixin(CreateFrame("Frame", nil, bag), AuctionatorGroupsViewGroupMixin)
            g.GroupTitle = CreateFrame("Button", nil, g)
            g.GroupTitle:GetFontString():SetFont(FONT, 13, "OUTLINE")
            groups[i] = g
        end
        g:SetName(n[1], n[2])
        g:Show()
    end
end
