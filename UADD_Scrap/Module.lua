-- UADD - Scrap: start-up, on and off, the status line and "/uadd scrap ...".
--
-- Scrap keeps its words in an AceLocale table and reads most of them when it shows them. Swap.lua puts ours
-- in the table (and the four key binding names), Screen.lua in what Scrap wrote once (settings page names,
-- the junk list's tabs and buttons, the tutorial), Fonts.lua gives our words a font with Ukrainian letters.
-- No English is stored here: it is read from Scrap at run time.
--   * Never ours: item names, and the chat lines with an item link in them (lesson 9). The junk list shows
--     each item's name taken from UALL Forever (Items.lua); one it lacks stays English. The "Scrap" tab and
--     title are the addon's name and stay. Scrap saves no text of the table in its data (lesson 14).
--   * Scrap's settings (Scrap_Config) and its junk list (Scrap_Merchant) load later, on their own: each gets
--     ours when it loads.
--   * Off, and while the hold key is held (UADD/Original.lua): the English goes back everywhere it went in.
-- On a client that is not English the module does nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "Scrap"
local LATER = { Scrap_Config = true, Scrap_Merchant = true }

ns.AL = ns.AL or {}
ns.SORT = ns.SORT or {}

local function Say(msg) U.Print("Scrap: " .. msg) end

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

-- ── On and off ────────────────────────────────────────────────────────────────────────────────

local function Apply(on)
    if on then
        U.SafeCall(ns.Swap.SwapIn)
        U.SafeCall(ns.Screen.Apply)
        U.SafeCall(ns.Items.Set, true)
    else
        U.SafeCall(ns.Items.Set, false)
        U.SafeCall(ns.Screen.Restore)
        U.SafeCall(ns.Swap.SwapOut)
    end
    U.SafeCall(ns.Screen.Tutorial)
    U.SafeCall(ns.Fonts.Sync)
end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Fonts.Install)
    Apply(ns.WordsWanted())
    U.SafeCall(ns.Fonts.Scan)
end

local function End()
    Apply(false)
    U.SafeCall(ns.Fonts.Restore)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: one word alone (an item or a patron's name), a line with
-- no small letters, the copyright line under the patrons.
local function Keep(_, plain)
    if type(plain) ~= "string" then return false end
    return not plain:find("%s") or not plain:find("%l") or plain:find("^Copyright") ~= nil
end

local function Ready()
    if ready or not db or not Loaded(TARGET) or not ns.Swap.Locale() then return end
    ready = true
    U.SafeCall(U.MissedModule, "scrap", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Swap.Translate(t) ~= nil end })
    Begin()
end

-- A part of Scrap that loaded later: its words after it built its frames.
local function Later()
    if not ns.On() then return end
    U.SafeCall(ns.Fonts.Install)
    Apply(ns.WordsWanted())
    U.SafeCall(ns.Fonts.Scan)
end

-- Scrap loads before us (an optional dependency), so the words go in when we load: its settings and junk
-- list, loaded later, then read ours. Again at login, in case Scrap was late.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("scrap")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
            U.SafeCall(Ready)
        elseif LATER[name] and ready then
            C_Timer.After(0, function() U.SafeCall(Later) end)
        end
    else
        U.SafeCall(Ready)
    end
end)

-- The hold key: Scrap's English while it is held, our words again after.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        Apply(ns.WordsWanted())
    end, "Scrap")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Scrap не завантажено" end
    if not db.enabled then return "вимкнено (/uadd scrap on)" end
    return ("увімкнено: Scrap українською; текстів наших: %d, змінено у вікнах: %d, з нашим шрифтом: %d")
        :format(ns.Swap.Count(), ns.Screen.Count(), ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd scrap on - Scrap українською",
    "/uadd scrap off - вимкнути, Scrap знову англійською",
    "Назви предметів у списку - з UALL Forever; яких там немає, лишаються англійською.",
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
        Say("вимкнено. Scrap знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("scrap", { title = "Scrap", Status = Status, Command = Command })
