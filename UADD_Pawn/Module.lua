-- UADD - Pawn: start-up, on and off, the status line and "/uadd pawn ...".
--
-- Pawn keeps its words in the global table PawnLocal and copies many of them while it loads (UIStrings.lua,
-- PawnUI.xml). Swap.lua puts ours in both places and Pawn's English back; Fonts.lua gives our words a font
-- with Ukrainian letters. No English is stored here: it is read from Pawn at run time.
--   * Never ours: its tooltip parsing, number separators, spec names and debug lines (Pawn reads or compares
--     them), and words Pawn saves into the player's data (lesson 14): those show ours only on screen.
--   * Off, and while the hold key is held (UADD/Original.lua): the English goes back everywhere it went in,
--     also into the labels Pawn set once (lesson 15).
-- On a client that is not English the module does nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "Pawn"

ns.AL = ns.AL or {}
ns.SORT = ns.SORT or {}

local function Say(msg) U.Print("Pawn: " .. msg) end

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
    local S = ns.Swap
    if on then
        U.SafeCall(S.SwapIn)
        U.SafeCall(S.Scan, true)
    else
        U.SafeCall(S.Scan, false)
        U.SafeCall(S.SwapOut)
    end
    U.SafeCall(S.Refresh)
    U.SafeCall(ns.Fonts.Sync)
end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Swap.Install)
    U.SafeCall(ns.Fonts.Install)
    Apply(ns.WordsWanted())
end

local function End()
    Apply(false)
    U.SafeCall(ns.Fonts.Restore)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: one word alone (a scale name, a key), a number.
local function Keep(_, plain)
    return type(plain) == "string" and not plain:find("%s")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) or type(rawget(_G, "PawnLocal")) ~= "table" then return end
    ready = true
    U.SafeCall(U.MissedModule, "pawn", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Swap.Translate(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("pawn")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
            U.SafeCall(Ready)
        end
    else
        U.SafeCall(Ready)
        if ns.On() then
            U.SafeCall(ns.Fonts.Install)
            U.SafeCall(ns.Fonts.Scan)
        end
    end
end)

-- The hold key: Pawn's English while it is held, our words again after.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        Apply(ns.WordsWanted())
    end, "Pawn")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Pawn не завантажено" end
    if not db.enabled then return "вимкнено (/uadd pawn on)" end
    return ("увімкнено: Pawn українською; текстів наших: %d, змінено у вікнах: %d, з нашим шрифтом: %d")
        :format(ns.Swap.Count(), ns.Swap.Frames(), ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd pawn on - Pawn українською",
    "/uadd pawn off - вимкнути, Pawn знову англійською",
    "Назви шкал (ваші й вбудовані) лишаються такими, як є.",
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
        Say("вимкнено. Pawn знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("pawn", { title = "Pawn", Status = Status, Command = Command })
