-- UADD - GearQuest Forever: start-up, on and off, the hold key, the status line and "/uadd gq ...".
--
-- Locale.lua plugs our Ukrainian into GearQuest's locale table and its language list, Fonts.lua gives a Cyrillic
-- face where it pins its own, Screen.lua switches the texts already drawn, Menu.lua its right-click menu, copy box
-- and notices.
--   * Ukrainian is in force while the module is on and its language list says Українська or nothing (auto).
--     English picked there (or its English interface switch) keeps its English; another language is GearQuest's.
--     Its saved setting is never changed by us.
--   * Off, and while the hold key is held (UADD/Original.lua): its English, in windows already open too.
--   * Never in combat (lesson 36): a switch then waits for the fight's end and happens whole.
--   * Its sentences, quest texts, names and phrase rules stay as GearQuest gives them (its English): game names
--     come from ClassicUA and UALL Forever, and nothing of ours makes a half line there.
-- On a client that is not English the module does nothing. No English of GearQuest is stored here.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "GearQuestForever"

ns.AL = ns.AL or {}
ns.SORT = ns.SORT or {}

local function Say(msg) U.Print("GearQuest Forever: " .. msg) end

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
    return ns.On() and not U.originalShown and ns.Loc.Choice() == "uk"
end

local function Fighting()
    local ok, yes = pcall(InCombatLockdown)
    return ok and yes == true
end

-- ── On and off ────────────────────────────────────────────────────────────────────────────────

local Sync
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

-- Ours in (true) or its words back (false): the lookup, the load-time words, the open windows, the faces.
local function Apply(on)
    if Fighting() then return Later() end
    U.SafeCall(ns.Loc.Set, on)
    U.SafeCall(ns.Screen.Sync, on)
    U.SafeCall(ns.Glued.Sync, on)
    U.SafeCall(ns.Menu.Sync, on)
end

-- The state it should be in now; nothing when it is in it already (unless `force`).
Sync = function(force)
    local want = ns.WordsWanted()
    if not force and want == ns.Loc.InForce() then return end
    Apply(want)
end
ns.Sync = Sync

local function Begin()
    if not ns.On() then return end
    if not U.SafeCall(ns.Loc.Install) or not ns.Loc.Installed() then return end
    U.SafeCall(ns.Fonts.Install)
    U.SafeCall(ns.Glued.Install)
    U.SafeCall(ns.Menu.Install)
    Sync(true)
end

-- Off (db.enabled is false by now): its English back, now or when the fight ends. The wraps stay but do nothing.
local function End() Apply(false) end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: a line with no small letters.
local function Keep(_, plain)
    return type(plain) ~= "string" or not plain:find("%l")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) or not ns.Loc.Addon() then return end
    ready = true
    U.SafeCall(U.MissedModule, "gq", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Loc.Text(t) ~= nil end })
    -- Its font calls are wrapped also while off: the texts it pins then are known, so "on" later puts our face on
    -- them (no boxes). While off the wraps only take note.
    U.SafeCall(ns.Fonts.Install)
    Begin()
end

-- GearQuest loads before us (a dependency): ours goes in when we load, so the windows it builds at login read
-- ours. Its language step may have run already (its settings load first): Sync covers both. At login once more.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        db = U.DB("gq")
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
    end, "GearQuest Forever")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: GearQuest Forever не завантажено" end
    if not db.enabled then return "вимкнено (/uadd gq on)" end
    if not ns.Loc.Installed() then return "не працює: GearQuest Forever змінився, тексти лишаються англійською" end
    local choice = ns.Loc.Choice()
    if choice == "en" then return "чекає: у налаштуваннях GearQuest Forever вибрано англійську" end
    if choice == "other" then return "чекає: у налаштуваннях GearQuest Forever вибрано іншу мову" end
    return ("увімкнено: GearQuest Forever українською; текстів наших: %d, змінено у вікнах: %d, з нашим шрифтом: %d")
        :format(ns.Loc.Count(), ns.Screen.Count(), ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd gq on - GearQuest Forever українською",
    "/uadd gq off - вимкнути, GearQuest Forever знову англійською",
    "Українська діє, коли в списку мов GearQuest Forever вибрано «Українська» або нічого не вибрано.",
    "Назви предметів, зон, завдань і NPC дають ClassicUA та UALL Forever.",
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
        Say("вимкнено. GearQuest Forever знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("gq", { title = "GearQuest Forever", Status = Status, Command = Command })
