-- UADD - Auto Potion: start-up, the status line and "/uadd autopotion ...".
--
-- Auto Potion's own words (its six settings pages, their tooltips, its chat lines and its key binding
-- names) in Ukrainian. Auto Potion reads its locale table once, while it loads, and sets every label
-- before this module runs, so its table is not changed: the words are swapped where they show.
--   * data/words.lua (made by tools/make_ap_text.py) has hashes of its English texts and our Ukrainian.
--     Words.lua turns a shown English text into Ukrainian.
--   * Screen.lua finds the FontStrings of its pages; Texts.lua hooks each one's SetText and keeps its
--     English; Fonts.lua gives our words a font with Ukrainian letters; Tooltip.lua does the tooltips
--     over its check boxes, Chat.lua its chat lines, Bindings.lua its Key Bindings lines.
--   * The five macro names (and the macros themselves), its saved settings and the lines of its debug
--     log stay English. The chat lines that say its debug mode is on or off are ours (Chat.lua).
--     Spell, item and class names are the game's (UALL Forever's), never ours: Game.lua takes the class
--     headers and the spell and item names on its check boxes from UALL Forever; one it lacks stays English.
-- While the hold key is held (UADD/Original.lua) the words are English again. "/uadd autopotion off"
-- puts everything back as Auto Potion had it. On a client that is not English the module does nothing.
-- UALL Forever has no hooks for Auto Potion (checked against UALLF 1.0.17), so nothing is left to it.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "AutoPotion"

local function Say(msg) U.Print("Auto Potion: " .. msg) end

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

-- Texts it keeps English on purpose, for U.Missed: the macro names, and one word alone (a name).
local function Keep(_, plain)
    return type(plain) == "string" and not plain:find("%s")
end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Chat.Start)
    U.SafeCall(ns.Tooltip.Install)
    U.SafeCall(ns.Bindings.Apply, not U.originalShown)
    U.SafeCall(ns.Screen.Install)
    U.SafeCall(ns.Screen.Scan)
end

local function End()
    U.SafeCall(ns.Chat.Stop)
    U.SafeCall(ns.Bindings.Apply, false)
    ns.Screen.Restore()
end

-- Auto Potion is there (loaded before us, it is a dependency): build the word tables once and start.
local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(ns.Words.Build)
    U.SafeCall(U.MissedModule, "autopotion", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Words.Text(t) or ns.Words.Bare(t) end,
        index = function() return ns.Words.Index() end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("autopotion")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
            U.SafeCall(Ready)
        end
    else
        U.SafeCall(Ready)
        U.SafeCall(ns.Bindings.Apply, ns.WordsWanted())   -- the binding list is complete by now
        U.SafeCall(ns.Screen.Scan)
        self:UnregisterAllEvents()
    end
end)

-- The hold key: only what is shown changes now (hidden texts when they show).
if U.OnOriginal then
    U.OnOriginal(function(show)
        if not ns.On() then return end
        ns.Texts.Sync()
        ns.Tooltip.Sync(show)
        U.SafeCall(ns.Bindings.Apply, not show)
    end, "Auto Potion")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Auto Potion не завантажено" end
    if not db.enabled then return "вимкнено (/uadd autopotion on)" end
    return ("увімкнено: Auto Potion українською; слів: %d, текстів перекладено: %d, шрифтів виправлено: %d")
        :format(ns.Words.Count(), ns.Texts.Count(), ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd autopotion on - Auto Potion українською",
    "/uadd autopotion off - вимкнути, Auto Potion знову такий, як без UADD",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd = args:lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled then return Say("вже увімкнено.") end
        db.enabled = true
        Begin()
        Say("увімкнено.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        db.enabled = false
        End()
        Say("вимкнено. Auto Potion знову такий, як без UADD.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("autopotion", { title = "Auto Potion", Status = Status, Command = Command })
