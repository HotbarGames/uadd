-- UADD_LiteMount: LiteMount's own words in Ukrainian (its settings panels, rules, menus, tooltips, chat).
-- Locale.lua: our words in its L table, in place; Tables.lua: the words it copied at load into its own tables,
-- its dialogs and key binding names; Copies.lua: its filter menu, its General page and its rule errors;
-- Screen.lua: the texts its panels copied at load.
-- Left English: mount model names (its MountDB), its bug report dump, its translators list, its slash command
-- help and macro text, the keys it fills from game globals, and any line whose slot holds a game name.
-- The way in is LiteMount.LM.L; when it is not there the module waits and changes nothing.
-- Any error turns the module off: English as it was.
local ADDON, ns = ...
local U = UADD
local TARGET = "LiteMount"
local KEY = "litemount"

local db, ready = nil, false

local function Say(msg) U.Print("LiteMount: " .. msg) end

local function EnglishClient()
    local l = type(GetLocale) == "function" and GetLocale() or "enUS"
    return l == "enUS" or l == "enGB"
end

local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local ok, yes = pcall(fn, name)
    return ok and yes and true or false
end

function ns.On()
    return ready and db ~= nil and db.enabled == true and EnglishClient() and ns.Locale.Found()
end
function ns.WordsWanted() return ns.On() and not U.originalShown end

-- Its StaticPopup dialogs (LM_OPTIONS_*): the game's ACCEPT, CANCEL, DELETE and OKAY on their buttons are
-- ours while the global is English, through the core helper (UADD/Popups.lua); Tables.lua writes their texts.
U.Popups.Register(KEY, {
    prefix = "LM_OPTIONS_",
    globals = { ACCEPT = "ui.accept", CANCEL = "ui.cancel", DELETE = "ui.delete", OKAY = "ui.ok" },
    wanted = function() return ns.WordsWanted() end,
})

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Locale.Sync)
    U.SafeCall(ns.Copies.Sync)
    U.SafeCall(ns.Tables.Sync)
    U.Popups.Sync(KEY)
    U.SafeCall(ns.Screen.Hook)
    U.SafeCall(ns.Screen.Apply)
end

local function End()
    U.SafeCall(ns.Copies.Restore)
    U.SafeCall(ns.Tables.Restore)
    U.Popups.Off(KEY)
    U.SafeCall(ns.Locale.Restore)
    U.SafeCall(ns.Screen.Restore)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: one word alone (a name, a key, a number), its own name.
local function Keep(_, plain)
    return type(plain) == "string" and (not plain:find("%s") or plain == "LiteMount")
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
    else
        U.SafeCall(Ready)
        Begin()                                         -- its panels and its dialogs are all made by now
    end
end))

-- The hold key: the English while it is held, our words again after (lesson 15).
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        U.SafeCall(ns.Locale.Sync)
        U.SafeCall(ns.Copies.Sync)
        U.Popups.Sync(KEY)
        U.SafeCall(ns.Tables.Sync)
        U.SafeCall(ns.Screen.Apply)
    end, "LiteMount")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: LiteMount не завантажено" end
    if not ns.Locale.Found() then return "чекає: таблицю слів LiteMount не знайдено, усе англійською" end
    if not db.enabled then return "вимкнено (/uadd litemount on)" end
    local seen, ours = ns.Screen.Count()
    return ("увімкнено: LiteMount українською; текстів: %d, у таблиці: %d, на екрані: %d, з них наших: %d")
        :format(ns.Locale.Count(), ns.Locale.Written(), seen, ours)
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd litemount on - LiteMount українською",
    "/uadd litemount off - вимкнути, LiteMount знову англійською",
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
        Say("вимкнено. LiteMount знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule(KEY, { title = "LiteMount", Status = Status, Command = Command })
