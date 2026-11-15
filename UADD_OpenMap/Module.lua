-- UADD - OpenMap: start-up, the status line and "/uadd openmap ...".
--
-- All of OpenMap in Ukrainian: its menu on the World Map, the dungeon view, its options, the News
-- window and its page in the game's Settings.
--   * Locale.lua puts our words in OpenMap's own locale table (L), which OpenMap reads each time
--     it shows a text. Words.lua swaps the texts OpenMap read before that (once, as it loaded).
--   * Fonts.lua gives a Cyrillic font to the texts that need one: the client's standard font has
--     no Ukrainian letters (Questie's Ukrainian quest titles showed as squares on the dungeon view).
--   * Dungeon and boss names come from the names the other modules already saved.
-- While the hold key is held (UADD/Original.lua) the words are English again; the fonts stay, so
-- Questie's titles still read. "/uadd openmap off" puts everything back as OpenMap had it.

local ADDON, ns = ...
local U = UADD
local Fonts, Words, Screen, Locale = ns.Fonts, ns.Words, ns.Screen, ns.Locale
local db

local function Say(msg) U.Print("OpenMap: " .. msg) end

function ns.On() return db ~= nil and db.enabled == true end
function ns.WordsWanted() return ns.On() and not U.originalShown end

local function Init()
    db = U.DB("openmap")
    ns.db = db
    if db.enabled == nil then db.enabled = true end
    Screen.CatchPanel()           -- before OpenMap's PLAYER_LOGIN adds its page to Settings
    Locale.Sync()                 -- before OpenMap builds its options from L
    U.AceFont.Register("OpenMap", ns.On)   -- the options window's fonts (UADD/AceFont.lua)
end

-- Our words in L and on the shown texts, as they should be now (hold key, on, off).
local function Sync()
    U.SafeCall(Locale.Sync)
    U.SafeCall(Words.Sync)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        U.SafeCall(Init)
    else
        C_Timer.After(0, function() U.SafeCall(Screen.Install) end)
        U.SafeCall(ns.Tooltip.Install)
    end
end)

-- The hold key: not in combat (the look after combat puts the right words in).
if U.OnOriginal then
    U.OnOriginal(function() if not Screen.WaitCombat() then Sync() end end, "OpenMap")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not db.enabled then return "вимкнено (/uadd openmap on)" end
    return ("увімкнено: OpenMap українською; слів у таблиці OpenMap: %d, шрифтів виправлено: %d, текстів перекладено: %d")
        :format(Locale.Count(), Fonts.Count(), Words.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd openmap on - OpenMap українською",
    "/uadd openmap off - вимкнути, OpenMap знову такий, як без UADD",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd = args:lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled then return Say("вже увімкнено.") end
        db.enabled = true
        U.SafeCall(Screen.Install)
        U.SafeCall(Screen.Start)
        Sync()
        U.SafeCall(Screen.Scan)
        Say("увімкнено.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        db.enabled = false
        Screen.Stop()
        Sync()                          -- English back: our words are not wanted now
        U.SafeCall(Screen.Sweep)        -- and on texts built while L was ours, shown or not
        Fonts.Restore()
        U.AceFont.Stop("OpenMap")
        ns.Tooltip.Stop()
        Say("вимкнено. OpenMap знову такий, як без UADD.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("openmap", { title = "OpenMap", Status = Status, Command = Command })
