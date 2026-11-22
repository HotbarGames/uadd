-- UADD - OneForAll: start-up, on and off, the status line and "/uadd oneforall ...".
--
-- OneForAll has its own languages (enUS, deDE, frFR, esES, ptBR). UADD_OneForAll is ours only while OneForAll's
-- language is English (FLT.Language() == "enUS"); read once at login, since a change of its language needs a reload.
-- Its L, FLT.LNum and its name helpers stay English (its code matches their results); ours goes in where a text is
-- drawn. Where they show:
--   * its windows (the main window and its tabs, Settings, the info bar, the minimap and world map buttons, its own
--     popups and small windows): Screen.lua (the core walker, U.Walk);
--   * its chat lines and its tooltip lines: Chat.lua (U.ChatLines, U.TipLines).
-- Off, and while the hold key is held: its English everywhere it went in. Its saved data (OneForAllDB,
-- OneForAllCharDB), the game's globals and its addon messages are never written. On a client that is not English,
-- or with OneForAll in another language, the module does nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local ofaEnglish = false
local KEY, TITLE, TARGET = "oneforall", "OneForAll", "OneForAll"

local function Say(msg) U.Print(TITLE .. ": " .. msg) end

local function EnglishClient()
    local l = type(GetLocale) == "function" and GetLocale() or "enUS"
    return l == "enUS" or l == "enGB"
end

local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if type(fn) ~= "function" then return false end
    local ok, yes = pcall(fn, name)
    return ok and yes and true or false
end

-- OneForAll's language: its own FLT.Language(), or the same logic from its saved choice when that fails.
local OTHER = { deDE = true, frFR = true, esES = true, esMX = true, ptBR = true }
local function OfaLanguage()
    local F = rawget(_G, "OneForAll")
    local fn = type(F) == "table" and rawget(F, "Language")
    if type(fn) == "function" then
        local ok, lang = pcall(fn)
        if ok and type(lang) == "string" then return lang end
    end
    local saved = rawget(_G, "OneForAllDB")
    local lang = type(saved) == "table" and rawget(saved, "language") or "game"
    if lang == "game" then lang = type(GetLocale) == "function" and GetLocale() or "enUS" end
    if OTHER[lang] then return lang end
    return "enUS"
end

function ns.On() return ready and ofaEnglish and db ~= nil and db.enabled == true and EnglishClient() end
function ns.WordsWanted() return ns.On() and not U.originalShown end

-- Not U.Safe (lesson 19): hooks that also put the English back must run after an off for errors. An error is
-- reported and counted as U.Safe does (5 turn the module off); it never throws.
function ns.Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        err = tostring(err)
        pcall(U.ReportError, err)
        if type(U.Fault) == "function" then pcall(U.Fault, KEY, err) end
    end
end

local Screen, Chat, W = ns.Screen, ns.Chat, ns.Words

local function Sync()
    U.SafeCall(Screen.Sync)
    U.SafeCall(Chat.Sync)
end
ns.Sync = Sync

-- Begun in combat: the walker waits for the fight's end (U.AfterCombat); at PLAYER_REGEN_ENABLED it walks at once
-- (lesson 36).
local waited = false

local function Begin()
    if not ns.On() then return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then waited = true end
    U.SafeCall(Chat.Install)
    U.SafeCall(Screen.Install)
    Sync()
end

-- Off (db.enabled is false by now): everything of ours out.
local function End()
    U.SafeCall(Chat.Remove)
    U.SafeCall(Screen.Remove)
    W.Forget()
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: a line with no small letters, or one of the player's profiles.
local function Keep(_, plain)
    return type(plain) ~= "string" or not plain:find("%l") or Screen.ProfileName(plain)
end

local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    -- Its language is known once its saved data is in (PLAYER_LOGIN); before that, wait.
    if type(IsLoggedIn) == "function" and not IsLoggedIn() then return end
    ready = true
    ofaEnglish = OfaLanguage() == "enUS"
    if not ofaEnglish then return end
    U.SafeCall(U.MissedModule, KEY, { addon = TARGET, keep = Keep,
        test = function(t) return W.Translate(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_REGEN_ENABLED" then
        if not waited then return end
        waited = false
        if ns.On() then U.SafeCall(Screen.Install) end
    elseif event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB(KEY)
            ns.db = db
            if db.enabled == nil then db.enabled = true end
        elseif name ~= TARGET then
            return
        end
        U.SafeCall(Ready)
    else
        U.SafeCall(Ready)
        -- Its windows are made at login: walk again on the next frame.
        if ns.On() and C_Timer and C_Timer.After then C_Timer.After(0, function() U.SafeCall(Begin) end) end
    end
end)

-- The hold key: the walker gives its own texts back itself (U.Walk). Prints and tooltips ask each time.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        U.SafeCall(Chat.Sync)
    end, TITLE)
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: OneForAll не завантажено" end
    if not ofaEnglish then return "не працює: мова OneForAll не англійська (після зміни - /reload)" end
    if not db.enabled then return "вимкнено (/uadd oneforall on)" end
    return ("увімкнено: OneForAll українською; рядків у вікнах: %d, у чаті: %d, у підказках: %d")
        :format(Screen.Count(), Chat.Prints(), Chat.Tips())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd oneforall on - OneForAll українською",
    "/uadd oneforall off - вимкнути, OneForAll знову англійською",
    "Назви зон, підземель, предметів і завдань - з UALL Forever або ClassicUA; без них рядок лишається англійською.",
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
        Say("вимкнено. OneForAll знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule(KEY, { title = TITLE, Status = Status, Command = Command })

-- For the checks (tools/harness): the module's parts, by name.
ns.Status, ns.Command, ns.OfaLanguage = Status, Command, OfaLanguage
