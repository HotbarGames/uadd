-- UADD - Road to Sixty: start-up, on and off, the status line and "/uadd rts ...".
--
-- Road to Sixty has no locale tables: its texts are literals in its code, kept private. Words.lua knows ours by
-- the hash of each English literal. Where they show:
--   * its windows (the map window, panel, stats view and compare window, minimap button, What's New frame) and
--     its canvas in the game's Settings window: Screen.lua (the core walker, U.Walk);
--   * its prints, its tooltip lines and its three popups: Chat.lua (U.PrintHook, U.TipLines, U.Popups).
-- Off, and while the hold key is held: its English everywhere it went in. Its saved data, the game's globals, its
-- friends channel and the link its level-up line sends are never written. On a client that is not English the
-- module does nothing. No English of Road to Sixty is stored here.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local KEY, TITLE, TARGET = "rts", "Road to Sixty", "RoadToSixty"

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
        if type(U.Fault) == "function" then pcall(U.Fault, KEY, err) end
    end
end

local Screen, Chat, W = ns.Screen, ns.Chat, ns.Words

local function Sync()
    U.SafeCall(Screen.Sync)
    U.SafeCall(Chat.Sync)
end
ns.Sync = Sync

-- Begun in combat ("/uadd rts on" in a fight): the walker waits for the fight's end by a 1 s poll (U.AfterCombat).
-- At PLAYER_REGEN_ENABLED it walks at once (lesson 36), so ours shows as the fight ends, not up to a second later.
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

-- Texts it keeps English on purpose, for U.Missed: a line with no small letters.
local function Keep(_, plain)
    return type(plain) ~= "string" or not plain:find("%l")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
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
        -- Its Settings canvas is registered at login: walk again on the next frame.
        if ns.On() and C_Timer and C_Timer.After then C_Timer.After(0, function() U.SafeCall(Begin) end) end
    end
end)

-- The hold key: the walker gives its own texts back itself (U.Walk); the popups follow here. Prints and tooltips
-- ask each time.
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
    if not ready then return "чекає: Road to Sixty не завантажено" end
    if not db.enabled then return "вимкнено (/uadd rts on)" end
    return ("увімкнено: Road to Sixty українською; рядків у вікнах: %d, у чаті: %d, у підказках: %d")
        :format(Screen.Count(), Chat.Prints(), Chat.Tips())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd rts on - Road to Sixty українською",
    "/uadd rts off - вимкнути, Road to Sixty знову англійською",
    "Назви зон, предметів і завдань - з UALL Forever або ClassicUA; без них рядок лишається англійською.",
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
        Say("вимкнено. Road to Sixty знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule(KEY, { title = TITLE, Status = Status, Command = Command })

-- For the checks (tools/harness): the module's parts, by name.
ns.Status, ns.Command = Status, Command
