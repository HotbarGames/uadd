-- UADD - GatherMate2: start-up, on and off, the status line and "/uadd gathermate2 ...".
--
-- GatherMate2 keeps its words in an AceLocale table and copies many into its settings while it loads.
-- Swap.lua puts ours in the table (and the two key binding names), Options.lua in what it copied (settings,
-- page names, the Profiles tab, the key binding hint), Fonts.lua gives our words a font with Ukrainian
-- letters. No English is stored here: it is read from GatherMate2 at run time.
--   * Never ours: node, zone and profession names (game names it matches and compares: lesson 9), and the
--     chat line that glues an engine token. It saves no text of the table in its data (lesson 14).
--   * Off, and while the hold key is held (UADD/Original.lua): the English goes back everywhere it went in.
-- On a client that is not English the module does nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "GatherMate2"

ns.AL = ns.AL or {}
ns.SORT = ns.SORT or {}

local function Say(msg) U.Print("GatherMate2: " .. msg) end

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
        U.SafeCall(ns.Options.Apply)
    else
        U.SafeCall(ns.Options.Restore)
        U.SafeCall(ns.Swap.SwapOut)
    end
    U.SafeCall(ns.Fonts.Sync)
end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Options.Install)
    U.SafeCall(ns.Fonts.Install)
    Apply(ns.WordsWanted())
end

local function End()
    Apply(false)
    U.SafeCall(ns.Fonts.Restore)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: one word alone (a node, zone or profile name), a number.
local function Keep(_, plain)
    return type(plain) == "string" and not plain:find("%s")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) or not ns.Swap.Locale() then return end
    ready = true
    U.SafeCall(U.MissedModule, "gathermate2", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Swap.Translate(t) ~= nil end })
    Begin()
end

-- GatherMate2 registers its settings while it starts (OnInitialize/OnEnable), so the words go in at login,
-- after every addon started.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("gathermate2")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
        end
    else
        U.SafeCall(Ready)
    end
end)

-- The hold key: GatherMate2's English while it is held, our words again after.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        Apply(ns.WordsWanted())
    end, "GatherMate2")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: GatherMate2 не завантажено" end
    if not db.enabled then return "вимкнено (/uadd gathermate2 on)" end
    return ("увімкнено: GatherMate2 українською; текстів наших: %d, змінено в налаштуваннях: %d, з нашим шрифтом: %d")
        :format(ns.Swap.Count(), ns.Options.Count(), ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd gathermate2 on - GatherMate2 українською",
    "/uadd gathermate2 off - вимкнути, GatherMate2 знову англійською",
    "Назви трав, руд, риби, зон і професій лишаються такими, як їх дає гра.",
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
        Say("вимкнено. GatherMate2 знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("gathermate2", { title = "GatherMate2", Status = Status, Command = Command })
