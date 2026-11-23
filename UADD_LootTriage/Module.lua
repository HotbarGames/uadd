-- UADD - LootTriage: start-up, on and off, the status line and "/uadd lt ...".
--
-- LootTriage has no locale tables: its texts are literals in its code. Words.lua knows ours by the hash of
-- each English literal. Where they show:
--   * its lines in item tooltips (U.TipLines on GameTooltip: a line is tried only when it may be ours,
--     Words.Maybe, and only when LootTriage's files wrote it, lesson 12);
--   * its chat lines (U.ChatLines: its prefix, and its help lines with no prefix);
--   * its own settings window, its row in the game's Settings panel (Screen.lua), the word on the two buttons
--     that open its What's New (NewButton.lua), the game's menu its dropdowns open (Menu.lua: our font on our
--     names there). Its What's New dialog stays its English (lesson 43).
-- Off, and while the hold key is held: its English everywhere it went in. Its own names that it reads back
-- (the keep reasons it uses as keys, its saved choices) are never changed: only where they are drawn.
-- On a client that is not English the module does nothing. No English of it is stored here.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "LootTriage"
local PREFIX = "|cff33ff99LootTriage|r: "
local FROM = "AddOns[/\\]LootTriage[/\\]"

ns.LT = ns.LT or {}
ns.SORT = ns.SORT or {}

local function Say(msg) U.Print("LootTriage: " .. msg) end

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

-- Not U.Safe (lesson 19): hooks that also put the English back must run after an off for errors. An error is
-- reported and counted as U.Safe does (5 turn the module off); it never throws.
function ns.Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        err = tostring(err)
        pcall(U.ReportError, err)
        if type(U.Fault) == "function" then pcall(U.Fault, "lt", err) end
    end
end

local W = ns.Words
local tips = U.TipLines({ tips = { "GameTooltip" }, from = FROM, words = W, wanted = ns.WordsWanted, missed = "lt" })
local chat = U.ChatLines({ prefix = PREFIX, words = W, wanted = ns.WordsWanted })
local help = U.ChatLines({ from = FROM, wanted = ns.WordsWanted,
    words = { Translate = W.Translate, Maybe = W.ChatMaybe } })

local function Sync()
    U.SafeCall(ns.Screen.Sync)
    U.SafeCall(ns.NewButton.Sync)
    U.SafeCall(ns.Menu.Sync)
end
ns.Sync = Sync

local function Begin()
    if not ns.On() then return end
    U.SafeCall(W.Install)
    U.SafeCall(tips.Install)
    U.SafeCall(chat.Install)
    U.SafeCall(help.Install)
    U.SafeCall(ns.Screen.Install)
    U.SafeCall(ns.NewButton.Install)
    U.SafeCall(ns.Menu.Install)
    Sync()
end

-- Off (db.enabled is false by now): everything of ours out.
local function End()
    U.SafeCall(tips.Restore)
    U.SafeCall(chat.Restore)
    U.SafeCall(help.Restore)
    U.SafeCall(ns.NewButton.Sync)
    U.SafeCall(ns.Menu.Restore)                    -- before Screen.Remove gives every font of ours back
    U.SafeCall(ns.Screen.Remove)
    W.Forget()
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: a line with no small letters.
local function Keep(_, plain)
    return type(plain) ~= "string" or not plain:find("%l")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(U.MissedModule, "lt", { addon = TARGET, keep = Keep,
        test = function(t) return W.Translate(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        db = U.DB("lt")
        ns.db = db
        if db.enabled == nil then db.enabled = true end
        U.SafeCall(Ready)
    else
        U.SafeCall(Ready)
        if ns.On() then C_Timer.After(0, function() U.SafeCall(Begin) end) end
    end
end)

-- The hold key: its English while it is held, ours again after (the tooltip and chat hooks ask each time).
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        Sync()
    end, "LootTriage")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: LootTriage не завантажено" end
    if not db.enabled then return "вимкнено (/uadd lt on)" end
    return ("увімкнено: LootTriage українською; рядків у підказках: %d, у чаті: %d, у вікні: %d")
        :format(tips.Count(), chat.Count() + help.Count(), ns.Screen.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd lt on - LootTriage українською",
    "/uadd lt off - вимкнути, LootTriage знову англійською",
    "Назви предметів і завдань - з UALL Forever або ClassicUA; без них рядок лишається англійською.",
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
        db.enabled = false
        End()
        Say("вимкнено. LootTriage знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("lt", { title = "LootTriage", Status = Status, Command = Command })
