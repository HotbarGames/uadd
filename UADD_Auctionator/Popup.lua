-- Auctionator's questions in the game's StaticPopup dialogs (its own ones only: a name that starts with
-- "Auctionator", in any case: post at a low price, skip an item, cancel an auction you bid on, show all
-- hidden items, the shopping list dialogs) in Ukrainian, through the core helper UADD.Popups
-- (UADD/Popups.lua): the button fields hold our word while they hold the game's English (ACCEPT, CANCEL;
-- the globals are never written, a Cyrillic one stays), the shown dialog's text and buttons get our
-- words (Words.lua) and a font with Ukrainian letters, both ways on the hold key and off.
-- The game's BACK, NOT_BOUND and EMPTY show alone on Auctionator's frames (its Back buttons, a key that
-- has no binding, an empty list): Words.lua takes their pairs as exact texts (W.Build).

local _, ns = ...
local U = UADD
local P = {}
ns.Popup = P

local KEY = "auctionator"

U.Popups.Register(KEY, {
    prefix = "AUCTIONATOR",
    globals = { ACCEPT = "ui.accept", CANCEL = "ui.cancel", BACK = "ui.back", NOT_BOUND = "ui.not_bound",
        EMPTY = "ui.empty" },
    text = function(en) return ns.Words.Text(en) end,
    wanted = function() return ns.WordsWanted() end,
    fix = function(fs) ns.Fonts.Fix(fs) end,
    back = function(fs) ns.Fonts.Back(fs) end,
})

function P.Install() U.Popups.Sync(KEY) end

-- The hold key (and after combat): English or ours on the fields and the shown dialogs.
function P.Sync() U.Popups.Sync(KEY) end

-- "/uadd auctionator off": English and the fonts back.
function P.Restore() U.Popups.Off(KEY) end

-- The game's word pairs now, for Words.lua.
function P.Pairs() return U.Popups.Pairs(KEY) end

-- For the checks: how many dialogs show our words, and how many fields hold our word.
function P.Count() return U.Popups.Count(KEY) end
function P.FieldCount() return U.Popups.FieldCount(KEY) end
