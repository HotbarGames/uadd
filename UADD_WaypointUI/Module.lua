-- UADD_WaypointUI: Waypoint UI's own words in Ukrainian (its settings, prompts, the waypoint's distance and
-- arrival time, the pinpoint's grey line). Words.lua: the look-up and the units; Screen.lua: the route (each
-- ui-kit Text frame's own OnTextChanged event); Fonts.lua: a Cyrillic file on its own font objects.
-- Waypoint UI has no licence file (all rights reserved): data/text01.lua keeps only hashes of its English.
-- The player's names are never changed (lesson 13); its default pin names stay English in its data, because
-- they are saved with the pin (lesson 14, tools/wp_rules.py). A pin named after its map shows the map's name
-- from ClassicUA or UALL Forever where it is drawn (Words.lua Place). Any error turns the module off: English.
local ADDON, ns = ...
local U = UADD
local TARGET = "WaypointUI"
local KEY = "waypointui"

local db, ready = nil, false

local function Say(msg) U.Print("Waypoint UI: " .. msg) end

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

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Fonts.On)
    U.SafeCall(ns.Screen.Watch)
    U.SafeCall(ns.Screen.Apply)
end

local function End()
    U.SafeCall(ns.Screen.Restore)
    U.SafeCall(ns.Fonts.Off)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: one word alone (a name, a key), a number.
local function Keep(_, plain)
    return type(plain) == "string" and not plain:find("%s")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(U.MissedModule, KEY, { addon = TARGET, keep = Keep,
        test = function(t) return ns.Text(t) ~= nil or ns.Units(t) ~= nil end })
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
        Begin()                                         -- its frames are all made by now
    end
end))

-- The hold key: the English while it is held, our words again after (lesson 15).
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        if U.originalShown then U.SafeCall(ns.Screen.Restore) else U.SafeCall(ns.Screen.Apply) end
    end, "Waypoint UI")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Waypoint UI не завантажено" end
    if not db.enabled then return "вимкнено (/uadd waypointui on)" end
    local seen, ours = ns.Screen.Count()
    local note = next(ns.Fonts.odd) and "; обраний у Waypoint UI шрифт без українських літер" or ""
    return ("увімкнено: Waypoint UI українською; текстів: %d, на екрані: %d, з них наших: %d%s")
        :format(ns.Words.Count(), seen, ours, note)
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd waypointui on - Waypoint UI українською",
    "/uadd waypointui off - вимкнути, Waypoint UI знову англійською",
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
        Say("вимкнено. Waypoint UI знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule(KEY, { title = "Waypoint UI", Status = Status, Command = Command })
