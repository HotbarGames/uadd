-- UADD - DeleteCheapestItem Reloaded: start-up, on and off, the status line and "/uadd dci ...".
--
-- Its words sit in a private table we cannot reach, so Words.lua knows ours by the hash of each English text and
-- they are swapped where they show:
--   * its main window, its ignored items window and its settings page with the profiles part (Screen.lua);
--   * its own row tooltip and the lines it adds to the game's tooltip (its info button, its minimap button):
--     U.TipLines, a line of the game's tooltip tried only while the owner is its own (Words.Maybe) and only when
--     its files wrote the line (lesson 12);
--   * its chat lines (U.ChatLines, by its prefix);
--   * its profile question (U.Popups: our text, the game's yes and no while those are Latin).
-- Off, and while the hold key is held: its English everywhere it went in. The player's profile names stay as typed
-- (lesson 13). The game's own item delete question is left to the game. On a client that is not English the module
-- does nothing. No English of it is stored here.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local KEY = "dci"
local TARGET = "DeleteCheapestItem"
local TITLE = "DeleteCheapestItem Reloaded"
local PREFIX = "|cff7f7fff[" .. TITLE .. "] "
local FROM = "AddOns[/\\]DeleteCheapestItem[/\\]"
local POPUP = "DCI_PROFILE_ACTION"

ns.T = ns.T or {}
ns.SORT = ns.SORT or {}

local function Say(msg) U.Print(TITLE .. ": " .. msg) end

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

-- ns.Guard (lesson 19) is in Slots.lua: Screen.lua wraps its hooks with it while it loads.

local W = ns.Words
local tips = U.TipLines({ tips = { "GameTooltip" }, own = { "DCI_SecondTooltip" }, from = FROM, words = W,
    wanted = ns.WordsWanted, missed = KEY })
local chat = U.ChatLines({ prefix = PREFIX, words = W, wanted = ns.WordsWanted })

-- The profile question: our text (each block alone; the profile names kept as typed), and its English again for
-- a text it drew in our words.
local back, nback = {}, 0
local function PopText(en)
    -- The popup's text is set by the core helper, which does not look at the font: no Cyrillic font, no Ukrainian.
    if type(U.CyrFontPath) ~= "function" or type(U.CyrFontPath()) ~= "string" then return nil end
    local uk = W.Translate(en)
    if uk then
        if nback >= 50 then back, nback = {}, 0 end
        if back[uk] == nil then nback = nback + 1 end
        back[uk] = en
    end
    return uk
end
local function PopEnglish(uk) return back[uk] end
local popupsOk = type(U.Popups) == "table" and type(U.Popups.Register) == "function"
if popupsOk then
    U.Popups.Register(KEY, {
        names = { [POPUP] = true },
        globals = { YES = "ui.yes", NO = "ui.no" },
        text = PopText, english = PopEnglish, wanted = ns.WordsWanted,
        fix = function(fs) if ns.Screen then ns.Screen.Font(fs) end end,
        back = function(fs) if ns.Screen then ns.Screen.Unfont(fs) end end,
    })
end

local function Sync()
    U.SafeCall(ns.Screen.Sync)
    if popupsOk then U.SafeCall(U.Popups.Sync, KEY) end
end
ns.Sync = Sync

local function Begin()
    if not ns.On() then return end
    U.SafeCall(tips.Install)
    U.SafeCall(chat.Install)
    U.SafeCall(ns.Screen.Install)
    Sync()
end

-- Off (db.enabled is false by now): everything of ours out.
local function End()
    U.SafeCall(tips.Restore)
    U.SafeCall(chat.Restore)
    if popupsOk then U.SafeCall(U.Popups.Off, KEY) end
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
    U.SafeCall(U.MissedModule, KEY, { addon = TARGET, keep = Keep,
        test = function(t) return W.Translate(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        db = U.DB(KEY)
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
    end, TITLE)
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: " .. TITLE .. " не завантажено" end
    if not db.enabled then return "вимкнено (/uadd dci on)" end
    return ("увімкнено: %s українською; рядків у підказках: %d, у чаті: %d, у вікнах: %d")
        :format(TITLE, tips.Count(), chat.Count(), ns.Screen.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd dci on - " .. TITLE .. " українською",
    "/uadd dci off - вимкнути, " .. TITLE .. " знову англійською",
    "Назви предметів - з UALL Forever або ClassicUA; без них рядок лишається англійською.",
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
        Say("вимкнено. " .. TITLE .. " знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule(KEY, { title = TITLE, Status = Status, Command = Command })
