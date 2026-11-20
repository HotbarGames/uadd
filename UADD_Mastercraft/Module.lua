-- UADD - Mastercraft: start-up, the status line and "/uadd mastercraft ...".
--
-- Mastercraft's own words in Ukrainian: its windows and tabs, buttons, tooltips, pop-ups and chat lines.
-- Mastercraft itself stays on English; we change what it shows, one font string or line at a time:
--   * Words.lua: one English text to our Ukrainian (data/*.lua, made by tools/make_mc_text.py).
--   * Screen.lua: Mastercraft's font strings, with a font that has Ukrainian letters.
--   * Tooltip.lua: the lines it adds to tooltips. Chat.lua: its chat lines.
--   * Item, zone and NPC names come from UALL Forever; without one the whole line stays English.
-- While the hold key is held (UADD/Original.lua) Mastercraft's English is back. "/uadd mastercraft off"
-- puts everything back as Mastercraft had it. On a client that is not English the module does nothing.
-- Mastercraft_Inbox needs nothing: it only loads Mastercraft's mail code, whose texts are Mastercraft's.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "Mastercraft"

local function Say(msg) U.Print("Mastercraft: " .. msg) end

local function EnglishClient()
    local l = type(GetLocale) == "function" and GetLocale() or "enUS"
    return l == "enUS" or l == "enGB"
end

local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local ok, yes = pcall(fn, name)
    return ok and yes and true or false
end

-- On: turned on, an English client, and «Українська» (or nothing else) picked in Mastercraft's menu.
function ns.On() return ready and db ~= nil and db.enabled == true and EnglishClient() and ns.Lang.Wants() end
function ns.WordsWanted() return ns.On() and not U.originalShown end
function ns.Ready() return ready and EnglishClient() end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Screen.Install)
    U.SafeCall(ns.Tooltip.Install)
    U.SafeCall(ns.Chat.Install)
    U.SafeCall(ns.Screen.Scan)
    U.SafeCall(ns.Screen.Sync)
end
ns.Begin = Begin

local function End()
    U.SafeCall(ns.Screen.Sync)
    U.SafeCall(ns.Tooltip.Restore)
    U.SafeCall(ns.Chat.Restore)
end
ns.End = End

-- Texts it keeps English on purpose, for U.Missed: one word alone (a name, a game word), a number.
local function Keep(_, plain)
    return type(plain) == "string" and not plain:find("%s")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(U.MissedModule, "mastercraft", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Words.Translate(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("mastercraft")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
            U.SafeCall(Ready)
        end
    else
        U.SafeCall(Ready)
        U.SafeCall(ns.Lang.Install)
        if ns.On() then U.SafeCall(ns.Chat.Install) U.SafeCall(ns.Screen.Scan) end
    end
end)

-- The hold key: Mastercraft's English while it is held, our words again after.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        U.SafeCall(ns.Screen.Sync)
    end, "Mastercraft")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Mastercraft не завантажено" end
    if not db.enabled then return "вимкнено (/uadd mastercraft on)" end
    if not ns.Lang.Wants() then return "не працює: у меню мов Mastercraft вибрано іншу мову (/uadd mastercraft on)" end
    return ("увімкнено: Mastercraft українською; текстів: %d, на екрані з нашим шрифтом: %d")
        :format(ns.Words.Count(), ns.Screen.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd mastercraft on - Mastercraft українською",
    "/uadd mastercraft off - вимкнути, Mastercraft знову англійською",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd = (args or ""):lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled and ns.Lang.Wants() then return Say("вже увімкнено.") end
        db.enabled = true
        if db.choice == "other" then db.choice = "uk" end
        Begin()
        U.SafeCall(ns.Lang.Redraw)
        if not ns.Lang.MastercraftEnglish() then
            return Say("увімкнено, але Mastercraft зараз іншою мовою: виберіть «Українська» в його меню мов.")
        end
        Say("увімкнено.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        db.enabled = false
        End()
        U.SafeCall(ns.Lang.Redraw)
        Say("вимкнено. Mastercraft знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("mastercraft", { title = "Mastercraft", Status = Status, Command = Command })
