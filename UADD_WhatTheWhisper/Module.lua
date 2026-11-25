-- UADD - WhatTheWhisper: start-up, on and off, the status line and "/uadd wtw ...".
--
-- WhatTheWhisper keeps its words in its own locale tables and has a language list of its own in its settings.
-- Swap.lua puts ours in its English table (and in the copies it made at load), then this file asks it to
-- redraw the way its language list does (Options.Apply of its language setting: theme, layout, every
-- window, every text). Screen.lua does the few texts it wrote once, Days.lua the weekday names, Gaps.lua the
-- labels its enUS table lacks (the profile panel's rows, settings captions) and the History page's size line,
-- Lines.lua the zone alert, the export window's title and the icon picker.
--   * Only while English is the language in force in it: when the player picks another language in its
--     list, its English goes back first (its other languages fall back to that table), and ours comes back
--     when English is picked again. Its saved setting is never changed by us.
--   * Off, and while the hold key is held (UADD/Original.lua): its English everywhere it went in.
--   * Never in combat (lesson 36): a switch then waits for the fight's end and happens whole, so its windows
--     are all ours or all English, never a mix. One part goes at once: when the player picks another language
--     in combat, ours leaves its English table (that language falls back to it), and the rest waits.
--   * Its "save to a file" stays English (lesson 14; Swap.lua), and so does a group thread's name (Groups.lua).
-- On a client that is not English the module does nothing. No English of it is stored here.

local ADDON, ns = ...
local U = UADD
local db
local ready, hooked, busy = false, false, false
local TARGET = "WhatTheWhisper"

ns.AL = ns.AL or {}
ns.SORT = ns.SORT or {}

local function Say(msg) U.Print("WhatTheWhisper: " .. msg) end

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
function ns.WordsWanted()
    return ns.On() and not U.originalShown and ns.Swap.Active() == "enUS"
end

-- ── On and off ────────────────────────────────────────────────────────────────────────────────

-- Its own redraw for a language change, once its windows exist (after login).
local function Redraw()
    if type(IsLoggedIn) == "function" and not IsLoggedIn() then return end
    local a = ns.Swap.Addon()
    local O = a and a.Options
    if type(O) ~= "table" or type(O.Apply) ~= "function" then return end
    busy = true
    U.SafeCall(O.Apply, "appearance.locale")
    busy = false
end

local Sync

local function Fighting()
    local ok, yes = pcall(InCombatLockdown)
    return ok and yes == true
end

-- In combat: one wait for the fight's end, then the state of that moment, redrawn (lesson 36).
local waiting = false
local function Later()
    if waiting then return end
    waiting = true
    local function Try()
        if U.AfterCombat(Try) then return end
        waiting = false
        U.SafeCall(Sync, true)
    end
    Try()
end
ns.Waiting = function() return waiting end      -- for the checks

-- In combat all of it waits (Later), except that with another language in force ours leaves its English
-- table at once: a plain table write, and that language draws its gaps from that table.
local function InCombat(on)
    if ns.Swap.Active() == "enUS" then return Later() end
    if not on then U.SafeCall(ns.Swap.SwapOut) end
    Later()
end

-- Ours in (true) or its words back (false), its redraw, and on off its own day names and save back: all in
-- one go, out of combat.
local function Apply(on)
    if Fighting() then return InCombat(on) end
    U.SafeCall(on and ns.Swap.SwapIn or ns.Swap.SwapOut)
    if not ns.On() then
        U.SafeCall(ns.Days.Remove)
        U.SafeCall(ns.Swap.Remove)
        U.SafeCall(ns.Gaps.Remove)
        U.SafeCall(ns.Lines.Remove)
        U.SafeCall(ns.Groups.Remove)
    end
    Redraw()
    U.SafeCall(on and ns.Screen.Apply or ns.Screen.Restore)
    U.SafeCall(ns.Lines.Refresh)
end

-- The state it should be in now; nothing when it is in it already (unless `force`).
Sync = function(force)
    local want = ns.WordsWanted()
    if not force and want == ns.Swap.On() then return end
    Apply(want)
end
ns.Sync = Sync

-- After any change of its settings (its language list, a profile switch): ours in or out to match.
local function AfterApply()
    if busy or not ns.On() then return end
    Sync()
end

-- Not U.Safe (lesson 19): after an off for errors U.Safe stays dead for the session, so after "/uadd wtw on"
-- a language picked in its list would leave ours in its enUS table, and that language would fall back to ours.
-- This one stops only with our on flag (AfterApply checks ns.On()); an error is reported and counted as U.Safe
-- does (5 turn the module off); it never throws.
local function Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        err = tostring(err)
        pcall(U.ReportError, err)
        if type(U.Fault) == "function" then pcall(U.Fault, "wtw", err) end
    end
end

local function Hook()
    local a = ns.Swap.Addon()
    local O = a and a.Options
    if hooked or type(O) ~= "table" then return end
    hooked = true
    if type(O.Apply) == "function" then hooksecurefunc(O, "Apply", Guard(AfterApply)) end
    if type(O.ApplyAll) == "function" then hooksecurefunc(O, "ApplyAll", Guard(AfterApply)) end
end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(Hook)
    U.SafeCall(ns.Days.Install)
    U.SafeCall(ns.Swap.Install)
    U.SafeCall(ns.Gaps.Install)
    U.SafeCall(ns.Groups.Install)
    U.SafeCall(ns.Lines.Install)
    Sync(true)
    U.SafeCall(ns.Groups.Repair)
end

-- Off (db.enabled is false by now): everything of ours out in one go, now or when the fight ends (Apply).
local function End()
    if Fighting() then return Apply(false) end
    U.SafeCall(ns.Days.Remove)
    U.SafeCall(ns.Swap.Remove)
    U.SafeCall(ns.Gaps.Remove)
    U.SafeCall(ns.Lines.Remove)
    U.SafeCall(ns.Groups.Remove)
    Apply(false)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: a line with no small letters, and STAY.
local function Keep(_, plain)
    if type(plain) ~= "string" then return false end
    return not plain:find("%l") or ns.Swap.Known("L." .. U.Hash(plain))
end

local function Ready()
    if ready or not db or not Loaded(TARGET) or not ns.Swap.Base() then return end
    ready = true
    U.SafeCall(U.MissedModule, "wtw", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Swap.Translate(t) ~= nil end })
    Begin()
end

-- WhatTheWhisper loads before us (a dependency), so ours goes in when we load: its windows, made at login,
-- read ours. At login once more: its settings page and its windows exist now.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        db = U.DB("wtw")
        ns.db = db
        if db.enabled == nil then db.enabled = true end
        U.SafeCall(Ready)
    else
        U.SafeCall(Ready)
        if ns.On() then C_Timer.After(0, function() U.SafeCall(Sync, true) end) end
    end
end)

-- The hold key: its English while it is held, ours again after.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        Sync()
    end, "WhatTheWhisper")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: WhatTheWhisper не завантажено" end
    if not db.enabled then return "вимкнено (/uadd wtw on)" end
    if ns.Swap.Active() ~= "enUS" then
        return "чекає: у налаштуваннях WhatTheWhisper вибрано іншу мову; українська - коли вибрано англійську"
    end
    return ("увімкнено: WhatTheWhisper українською; текстів наших: %d, змінено у вікнах: %d, з нашим шрифтом: %d")
        :format(ns.Swap.Count(), ns.Screen.Count(), ns.Screen.Fonts())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd wtw on - WhatTheWhisper українською",
    "/uadd wtw off - вимкнути, WhatTheWhisper знову англійською",
    "Українська діє, коли в списку мов WhatTheWhisper вибрано англійську (або автоматично).",
    "Ваші повідомлення, імена і швидкі відповіді не змінюються.",
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
        Say("вимкнено. WhatTheWhisper знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("wtw", { title = "WhatTheWhisper", Status = Status, Command = Command })
