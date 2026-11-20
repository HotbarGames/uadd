-- UADD_ForeverQuestPins: Forever Quest Pins' own words in Ukrainian (its settings page, the World Map menu,
-- its first-run setup, the breadcrumb dialog, its chat lines, What's New).
-- Locale.lua: our words in its L table, in place; Screen.lua: the frames it builds once, both ways;
-- Menu.lua: its World Map menu checkboxes; Breadcrumb.lua and Chat.lua: the lines with game names, built whole.
-- Game names (quest titles, zones) come from the game, ClassicUA or UALL Forever (UADD.UALL); a line with a
-- name none of them has stays whole English. Its debug texts, its chat prefix and its /fqp paths stay English.
-- Any error turns the module off: English as it was.
local ADDON, ns = ...
local U = UADD
local TARGET = "ForeverQuestPins"
local KEY = "foreverquestpins"

local db, ready = nil, false

local function Say(msg) U.Print("Forever Quest Pins: " .. msg) end

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
    U.SafeCall(ns.Locale.Sync)
    U.SafeCall(ns.Chat.Install)
    U.SafeCall(ns.Menu.Install)
    U.SafeCall(ns.Breadcrumb.Hook)
    U.SafeCall(ns.Screen.HookPanel)
    U.SafeCall(ns.Screen.Apply)
end

local function End()
    U.SafeCall(ns.Locale.Restore)
    U.SafeCall(ns.Screen.Restore)
    U.SafeCall(ns.Chat.Restore)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: one word alone (a name, a key, a number), its own name.
local function Keep(_, plain)
    return type(plain) == "string" and (not plain:find("%s") or plain == "Forever Quest Pins")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(U.MissedModule, KEY, { addon = TARGET, keep = Keep,
        test = function(t) return ns.Locale.Uk(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", U.Safe(KEY, function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB(KEY)
            ns.db = db
            if db.enabled == nil then db.enabled = true end
        end
        if name == ADDON or name == TARGET then U.SafeCall(Ready) end
        if name == "Blizzard_WorldMap" and ns.On() then U.SafeCall(ns.Menu.Install) end
    else
        U.SafeCall(Ready)
        Begin()                                         -- its frames and its menu are all made by now
    end
end))

-- The hold key: the English while it is held, our words again after (lesson 15).
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        U.SafeCall(ns.Locale.Sync)
        U.SafeCall(ns.Screen.Apply)
    end, "Forever Quest Pins")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Forever Quest Pins не завантажено" end
    if not db.enabled then return "вимкнено (/uadd foreverquestpins on)" end
    local seen, ours = ns.Screen.Count()
    return ("увімкнено: Forever Quest Pins українською; текстів: %d, у таблиці: %d, на екрані: %d, з них наших: %d")
        :format(ns.Locale.Count(), ns.Locale.Written(), seen, ours)
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd foreverquestpins on - Forever Quest Pins українською",
    "/uadd foreverquestpins off - вимкнути, Forever Quest Pins знову англійською",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd = (args or ""):lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled then return Say("вже увімкнено.") end
        db.enabled = true
        Begin()
        Say("увімкнено.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        End()
        db.enabled = false
        Say("вимкнено. Forever Quest Pins знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule(KEY, { title = "Forever Quest Pins", Status = Status, Command = Command })
