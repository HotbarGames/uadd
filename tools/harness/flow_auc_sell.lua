-- More Lua helpers for flow_auc.py (after flow_auc.lua, before the game starts): the Selling tab
-- and the Cancelling list of the Auctionator stand-in (tools/harness/auctionator/Selling.lua).
local H = HARNESS
local M = H.auc
local function S() return rawget(_G, "AuctionatorStandIn") end
local function NS() return H.ns.UADD_Auctionator end

-- The game's item classes (Enum.ItemClass and their names), for the Selling tab's bag groups. The
-- harness's Enum gives 0 for any field, so the real numbers are set here.
Enum.ItemClass = { Consumable = 0, Container = 1, Weapon = 2, Armor = 4, Reagent = 5, Projectile = 6, Tradegoods = 7,
    Recipe = 9, Quiver = 11, Questitem = 12, Key = 13, Miscellaneous = 15 }
local CLASS_NAME = { [0] = "Consumable", [1] = "Container", [2] = "Weapon", [4] = "Armor", [5] = "Reagent",
    [6] = "Projectile", [7] = "Trade Goods", [9] = "Recipe", [11] = "Quiver", [12] = "Quest", [13] = "Key",
    [15] = "Miscellaneous" }
C_Item.GetItemClassInfo = function(id) return CLASS_NAME[id] end
GetItemClassInfo = C_Item.GetItemClassInfo
function M.className(k) return CLASS_NAME[Enum.ItemClass[k]] end
-- Our Ukrainian for one item class (ui/locale.lua ns.UA_CLASS).
function M.uaClass(k) return NS().UA_CLASS[k] end

-- The Selling tab: its bag groups made (or named again), its history panel shown or hidden, what
-- the quantity box holds.
function M.bagView() S().BagView() end
function M.toggleHistory(on) S().ToggleHistory(on) end
function M.boxText() return S().quantityBox:GetText() end
function M.groupsHooked() return NS().Rows.Groups() end

-- The Cancelling list: one row per {coloured name, quantity}.
function M.owned(list)
    local data = {}
    for i, d in ipairs(list) do data[i] = { itemName = d[1], quantity = d[2] } end
    S().ShowResults("cancel", data)
end

-- UALL Forever's item names (UADD.UALL: UADD/uall.lua) as a small map: name -> Ukrainian. While
-- M.uallWait is set it answers "not now". M.uallAsked: how often it was asked.
function M.uallStub(map)
    local A = UADD.UALL
    M.uallWait, A.__asked = false, 0
    A.IsAvailable = function() return true end
    A.Item = function(en)
        A.__asked = A.__asked + 1
        if M.uallWait then return nil, true end
        return map[en]
    end
end
function M.setUallWait(on) M.uallWait = on and true or false end
function M.uallAsked() return UADD.UALL.__asked or 0 end

-- One item's name: the Selling tab's item (name, colour, item level or nil) and the buy panel's item
-- (its text as the results give it); how many such FontStrings Rows.lua hooked.
function M.saleItem(name, color, level) S().SaleItem(name, color, level) end
function M.buyItem(text) S().BuyItem(text) end
function M.namesHooked() return NS().Rows.Names() end
