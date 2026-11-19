-- UADD - What's Training?: start-up, the status line and "/uadd whatstraining ...".
--
-- What's Training? keeps its addon table (and its locale table L) private and stays on English. We change
-- what it shows, one font string or line at a time, with UADD's shared engine:
--   * ns.Words (UADD/Words.lua over data/*.lua, made by tools/make_wt_text.py): one English text to our
--     Ukrainian, or nil. ns.Words.Translate is the translate function the half-translation check calls.
--   * Screen.lua: its own font strings and buttons, with a font that has Ukrainian letters.
--   * ns.Tips (UADD/Lines.lua): the lines it adds to its own tooltips, and to the game tooltip (its
--     minimap and Broker tooltips). ns.Chat: its chat lines (it prints them with no name in front).
--   * Zone and NPC names come from UALL Forever; without one the whole line stays English. Spell names
--     stay English (UALL Forever has no route to them for us), and so does a line with one glued on.
--   * The Broker text (shown by another addon, in that addon's font) stays English.
-- The Blizzard trainer window and the spellbook are UALL Forever's: we never touch them.
-- While the hold key is held (UADD/Original.lua) the English is back. "/uadd whatstraining off" puts
-- everything back as What's Training? had it. On a client that is not English the module does nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "WhatsTraining"
local FROM = "AddOns[/\\]WhatsTraining[/\\]"

ns.Words = U.NewWords(ns.WT)

local function Say(msg) U.Print("What's Training?: " .. msg) end

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

ns.Tips = U.TipLines({
    tips = { "GameTooltip" },
    own = { "WhatsTrainingForeverTooltip", "WhatsTrainingTrainerTooltip", "WhatsTrainingTooltip",
        "WhatsTrainingMenuTooltip", "WhatsTrainingCompareTooltip", "WhatsTrainingTomeSpellTooltip",
        "WhatsTrainingSayaadTomeTooltip" },
    from = FROM, words = ns.Words, wanted = ns.WordsWanted, missed = "whatstraining",
})
ns.Chat = U.ChatLines({ from = FROM, words = ns.Words, wanted = ns.WordsWanted })

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Screen.Install)
    U.SafeCall(ns.Tips.Install)
    U.SafeCall(ns.Chat.Install)
    U.SafeCall(ns.Screen.Scan)
    U.SafeCall(ns.Screen.Sync)
end

local function End()
    U.SafeCall(ns.Screen.Sync)
    U.SafeCall(ns.Tips.Restore)
    U.SafeCall(ns.Chat.Restore)
end
ns.Begin = Begin

-- Texts it keeps English on purpose, for U.Missed: one word alone (a name, a game word), a number.
local function Keep(_, plain)
    return type(plain) == "string" and not plain:find("%s")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(U.MissedModule, "whatstraining", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Words.Translate(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("whatstraining")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
            U.SafeCall(Ready)
        end
    else
        U.SafeCall(Ready)
        if ns.On() then U.SafeCall(ns.Chat.Install) U.SafeCall(ns.Tips.Install) U.SafeCall(ns.Screen.Scan) end
    end
end)

-- The hold key: the English while it is held, our words again after.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        U.SafeCall(ns.Screen.Sync)
    end, "What's Training?")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: What's Training? не завантажено" end
    if not db.enabled then return "вимкнено (/uadd whatstraining on)" end
    return ("увімкнено: What's Training? українською; текстів: %d, на екрані з нашим шрифтом: %d")
        :format(ns.Words.Count(), ns.Screen.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd whatstraining on - What's Training? українською",
    "/uadd whatstraining off - вимкнути, What's Training? знову англійською",
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
        Say("вимкнено. What's Training? знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("whatstraining", { title = "What's Training?", Status = Status, Command = Command })
