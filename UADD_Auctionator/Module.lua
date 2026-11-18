-- UADD - Auctionator: start-up, the status line and "/uadd auctionator ...".
--
-- Auctionator's own words (its auction house tabs, buy panels, dialogs, settings pages, tooltip
-- price lines and chat lines) in Ukrainian on an English client. Auctionator itself is never changed:
--   * ui/locale.lua has our Ukrainian by its locale key (the English is read from its AUCTIONATOR_L_*
--     globals), ui/text.lua our Ukrainian for the English in its code, by hash (tools/make_auc_text.py).
--     Words.lua turns a shown English text into Ukrainian.
--   * Screen.lua finds its FontStrings; Texts.lua hooks each one's SetText and keeps its English;
--     Rows.lua catches result rows made later; Fonts.lua gives our words a font with Ukrainian
--     letters; Chat.lua does its chat lines, Tooltip.lua its tooltip lines, Popup.lua its StaticPopup
--     dialogs, Menu.lua its drop-downs.
--   * Its tables, its AUCTIONATOR_L_* texts, its saved variables, what the player types and the
--     texts it reads back from its widgets stay English: only what is drawn on screen changes.
-- While the hold key is held (UADD/Original.lua) the words are English again. "/uadd auctionator off"
-- puts everything back as Auctionator had it. On a client that is not English the module does nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false        -- Auctionator is loaded and the tables are built
local TARGET = "Auctionator"
-- New results in the auction house (pooled rows get new texts): one look, a moment later.
local RESULTS = { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED",
    "ITEM_SEARCH_RESULTS_UPDATED", "OWNED_AUCTIONS_UPDATED" }

local function Say(msg) U.Print("Auctionator: " .. msg) end

local function EnglishClient()
    local l = type(GetLocale) == "function" and GetLocale() or "enUS"
    return l == "enUS" or l == "enGB"
end

local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local ok, yes = pcall(fn, name)
    return ok and yes and true or false
end

function ns.On() return ready and db ~= nil and db.enabled == true and EnglishClient() end
function ns.WordsWanted() return ns.On() and not U.originalShown end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Chat.Start)
    U.SafeCall(ns.Tooltip.Install)
    U.SafeCall(ns.Popup.Install)
    U.SafeCall(ns.Menu.Install)
    U.SafeCall(ns.Screen.Install)
    U.SafeCall(ns.Rows.Install)
    U.SafeCall(ns.Screen.Scan)
    local ah = rawget(_G, "AuctionHouseFrame")       -- turned on while the auction house is open
    if type(ah) == "table" and ah.IsShown and ah:IsShown() then U.SafeCall(ns.Screen.AuctionHouse, true) end
end

local function End()
    ns.Screen.Stop()
    U.SafeCall(ns.Chat.Stop)
    if not ns.Screen.WaitCombat() then ns.Screen.Restore() end   -- else when combat ends
end

-- Auctionator is there (loaded before us, or now): build the word tables once and start.
local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(ns.Words.Build)
    -- English texts it shows without our words are noted (UADD/Missed.lua); fixed ones go now.
    U.SafeCall(U.MissedModule, "auctionator", { addon = TARGET, test = function(t) return ns.Words.Text(t) end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
for _, event in ipairs(RESULTS) do pcall(frame.RegisterEvent, frame, event) end   -- not on every client
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("auctionator")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
        end
        if name == ADDON or name == TARGET then U.SafeCall(Ready) end
    elseif event == "PLAYER_LOGIN" then
        U.SafeCall(Ready)
        if ns.On() then U.SafeCall(ns.Screen.Install) end
        if ready then self:UnregisterEvent("ADDON_LOADED") end
    elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
        U.SafeCall(ns.Screen.AuctionHouse, event == "AUCTION_HOUSE_SHOW")
    else
        U.SafeCall(ns.Screen.Results)
    end
end)

-- The hold key: every known text changes now, hidden ones too; not in combat.
if U.OnOriginal then
    U.OnOriginal(function(show)
        if not ns.On() or ns.Screen.WaitCombat() then return end
        ns.Texts.Sync()
        ns.Tooltip.Sync(show)
        ns.Popup.Sync()
        ns.Menu.Sync()
        ns.Screen.Resize()
    end, "Auctionator")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Auctionator не завантажено" end
    if not db.enabled then return "вимкнено (/uadd auctionator on)" end
    return ("увімкнено: Auctionator українською; слів: %d, текстів перекладено: %d, шрифтів виправлено: %d")
        :format(ns.Words.Count(), ns.Texts.Count(), ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd auctionator on - Auctionator українською",
    "/uadd auctionator off - вимкнути, Auctionator знову такий, як без UADD",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd = args:lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled then return Say("вже увімкнено.") end
        db.enabled = true
        Begin()
        Say("увімкнено.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        db.enabled = false
        End()
        Say("вимкнено. Auctionator знову такий, як без UADD.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("auctionator", { title = "Auctionator", Status = Status, Command = Command })
