-- UADD - LayerSwap: start-up, the status line and "/uadd layerswap ...".
--
-- LayerSwap's own words (its panel, small bar, menus, options, tooltips and chat lines) in Ukrainian.
-- LayerSwap has no locale table, so nothing of it is changed:
--   * data/words.lua (made by tools/make_lsw_data.py) has hashes of its English texts and our Ukrainian.
--     Words.lua turns a shown English text into Ukrainian.
--   * Screen.lua finds its FontStrings and buttons; Texts.lua hooks each one's SetText and keeps its
--     English; Fonts.lua gives our words a font with Ukrainian letters; Chat.lua does its chat lines,
--     Tooltip.lua the tooltips over its frames.
--   * Its saved variables, its chat channel, the whispers and invites it sends, the lines it reads back
--     and its addon messages stay English: only what is drawn on screen changes.
-- While the hold key is held (UADD/Original.lua) the words are English again. "/uadd layerswap off"
-- puts everything back as LayerSwap had it. On a client that is not English the module does nothing.
-- It does not need UALL Forever (which has no hooks for LayerSwap, checked against UALLF 1.0.17).

local ADDON, ns = ...
local U = UADD
local db
local ready = false        -- LayerSwap is loaded and the tables are built
local TARGET = "LayerSwap"

local function Say(msg) U.Print("LayerSwap: " .. msg) end

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
    U.SafeCall(ns.Screen.Install)
    U.SafeCall(ns.Screen.Scan)
end

local function End()
    ns.Screen.Stop()
    U.SafeCall(ns.Chat.Stop)
    if not ns.Screen.WaitCombat() then ns.Screen.Restore() end   -- else when combat ends
end

-- LayerSwap is there (loaded before us, or now): build the word tables once and start.
local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(ns.Words.Build)
    -- English texts it shows without our words are noted (UADD/Missed.lua); fixed ones go now.
    U.SafeCall(U.MissedModule, "layerswap", { addon = TARGET, test = function(t) return ns.Words.Text(t) end,
        index = function() return ns.Words.Index() end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("layerswap")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
        end
        if name == ADDON or name == TARGET then U.SafeCall(Ready) end
    else
        U.SafeCall(Ready)
        U.SafeCall(ns.Screen.Install)
        U.SafeCall(ns.Screen.Scan)
        if ready then self:UnregisterEvent("ADDON_LOADED") end
    end
end)

-- The hold key: only what is shown changes now (hidden texts when they show); not in combat.
if U.OnOriginal then
    U.OnOriginal(function(show)
        if not ns.On() or ns.Screen.WaitCombat() then return end
        ns.Texts.Sync()
        ns.Tooltip.Sync(show)
    end, "LayerSwap")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: LayerSwap не завантажено" end
    if not db.enabled then return "вимкнено (/uadd layerswap on)" end
    return ("увімкнено: LayerSwap українською; слів: %d, текстів перекладено: %d, шрифтів виправлено: %d")
        :format(ns.Words.Count(), ns.Texts.Count(), ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd layerswap on - LayerSwap українською",
    "/uadd layerswap off - вимкнути, LayerSwap знову такий, як без UADD",
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
        Say("вимкнено. LayerSwap знову такий, як без UADD.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("layerswap", { title = "LayerSwap", Status = Status, Command = Command })
