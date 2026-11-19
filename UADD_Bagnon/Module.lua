-- UADD - Bagnon: start-up, the status line and "/uadd bagnon ...".
--
-- Bagnon's own words in Ukrainian: its bag, bank and guild bank windows (BagBrother's core), their
-- menus and tooltips, its chat lines and key binding names, and its settings pages (Bagnon_Config).
--   * data/*.lua (made by tools/make_bgn_text.py) have Bagnon's locale keys and our Ukrainian.
--     Locale.lua puts them into Bagnon's own AceLocale tables, so Bagnon shows them by itself, and puts
--     right the few words Bagnon read once while loading.
--   * Fonts.lua gives our words a font with Ukrainian letters, one FontString at a time.
--   * Item, spell, zone and NPC names are the game's (UALL Forever's), never ours. Words of the game
--     itself that Bagnon uses (bank, search, options and the like) are the game's and are not changed.
--     A few lines stay English because Bagnon glues them to such a word (tools/make_bgn_text.py: STAY).
-- While the hold key is held (UADD/Original.lua) Bagnon's English is back. "/uadd bagnon off" puts
-- everything back as Bagnon had it, but for the page names in the game's Settings list, which the game
-- keeps from when Bagnon_Config loaded: those change at the next /reload. On a client that is not
-- English the module does nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "Bagnon"
local LATER = { Bagnon_Config = true, Bagnon_Bank = true, Bagnon_GuildBank = true }

local function Say(msg) U.Print("Bagnon: " .. msg) end

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

-- Bagnon shows the new words: titles, the open windows, the tooltip under the mouse.
local function Refresh()
    local A = rawget(_G, TARGET)
    if type(A) == "table" and type(A.Frames) == "table" and A.Frames.Update then
        U.SafeCall(A.Frames.Update, A.Frames)
    end
    U.SafeCall(ns.Fonts.Sync)
    local tip, owner = GameTooltip, GameTooltip and GameTooltip:GetOwner()
    if tip and tip:IsShown() and owner and ns.Fonts.Ours(owner) and owner.GetScript then
        local enter = owner:GetScript("OnEnter")
        if enter then U.SafeCall(enter, owner) end
    end
end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Locale.Set, ns.WordsWanted())
    U.SafeCall(ns.Fonts.Install)
    U.SafeCall(ns.Fonts.Scan)
    Refresh()
end

local function End()
    U.SafeCall(ns.Locale.Set, false)
    Refresh()
    U.SafeCall(ns.Fonts.Restore)
end

-- Texts it keeps English on purpose, for U.Missed: one word alone (a name, a game word).
local function Keep(_, plain)
    return type(plain) == "string" and not plain:find("%s")
end

-- Bagnon is there (loaded before us, a dependency): start.
local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(U.MissedModule, "bagnon", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Locale.Ukrainian(t) end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("bagnon")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
            U.SafeCall(Ready)
        elseif LATER[name] and ns.On() then
            if name == "Bagnon_Config" then U.SafeCall(ns.Locale.ConfigLoaded)
            else U.SafeCall(ns.Locale.Patch, ns.WordsWanted()) end
            U.SafeCall(ns.Fonts.Install)
        end
    else
        U.SafeCall(Ready)
        U.SafeCall(ns.Locale.Patch, ns.WordsWanted())   -- the key binding list is complete by now
        U.SafeCall(ns.Fonts.Scan)
    end
end)

-- The hold key: Bagnon's English while it is held, our words again after.
if U.OnOriginal then
    U.OnOriginal(function(show)
        if not ns.On() then return end
        U.SafeCall(ns.Locale.Set, not show)
        Refresh()
    end, "Bagnon")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Bagnon не завантажено" end
    if not db.enabled then
        return "вимкнено (/uadd bagnon on); назви сторінок Bagnon у списку налаштувань гри — після /reload"
    end
    local s = ("увімкнено: Bagnon українською; текстів перекладено: %d, шрифтів виправлено: %d")
        :format(ns.Locale.Count(), ns.Fonts.Count())
    if ns.Locale.LateConfig() then
        s = s .. "; назви сторінок налаштувань Bagnon стануть українськими після /reload"
    end
    return s
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd bagnon on - Bagnon українською",
    "/uadd bagnon off - вимкнути, Bagnon знову англійською (назви сторінок у списку налаштувань гри - після /reload)",
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
        Say("вимкнено. Bagnon знову англійською; назви його сторінок у списку налаштувань гри - після /reload.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("bagnon", { title = "Bagnon", Status = Status, Command = Command })
