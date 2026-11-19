-- UADD - RareScanner: start-up, its locale table, the status line and "/uadd rarescanner ...".
--
-- RareScanner reads its words from an AceLocale table, GetLocale("RareScanner"): a plain table that it
-- reads each time a text shows. data/*.lua (made by tools/make_rs_text.py) hold our Ukrainian by
-- RareScanner's own locale key (ns.AL) and what each % slot holds (ns.SORT: v value, f free name,
-- n game name, t our own text, u a time span in RareScanner's own English units). No English is
-- stored here: it is read from that table at run time.
--   * On: for each key we have, RareScanner's English is kept (in memory) and ours goes in (rawset).
--     Off, and while the hold key is held (UADD/Original.lua): the English goes back.
--   * A key is used only when its % slots are the same, in the same order, as RareScanner's English.
--   * Never written: a template with an `n` slot (a game name: an NPC, a chest, an item) or a `u` slot
--     ("1h 5m"): what fills it may be English, so the line would be half Ukrainian (CLAUDE.md "No half
--     translations"): such a line stays all English. A `t` slot's words (INNER) must be ours too.
--     Also STAY below: CHAT_NOTIFICATION_RARE goes to the General channel, to other players; the rest
--     are saved in RareScanner's own data. They stay English.
--   * Words RareScanner read once while loading (its settings tables, its pop-ups, its settings page
--     names) are put right in Options.lua; Fonts.lua gives our words a font with Ukrainian letters.
-- On a client that is not English the module does nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "RareScanner"
local STAY = {
    CHAT_NOTIFICATION_RARE = true,    -- sent to the General channel, to other players
    CUSTOM_NPC_GROUP_DEFAULT = true,  -- these two are saved as a default group's name in RareScanner's
    EXPLORER_CUSTOM_ITEMS_GROUP_DEFAULT = true, -- saved data: ours would stay there with the module off
    CONTAINER = true,                 -- a nameless treasure's name: saved, then compared with this text
}
-- The words RareScanner fills into a template's `t` slots (tools/rs_rules.py INNER, kept the same by
-- tools/test_rs_text.py): the template is ours only when each of them is ours too.
local INNER = {
    EXPLORER_CREATE_BACKUP_DESC = { "EXPLORER_FILTERING" },
    EXPLORER_FILTERING_DESC = { "EXPLORER_FILTERS", "EXPLORER_FILTER_COLLECTIONS" },
    EXPLORER_FILTERING_DIALOG = { "EXPLORER_FILTERS", "EXPLORER_FILTER_COLLECTIONS", "EXPLORER_FILTER_MOUNTS",
        "EXPLORER_FILTER_TOYS" },
    FILTER_DESC = { "FILTER_TYPE_ALL", "FILTER_TYPE_WORLDMAP", "FILTER_TYPE_ALERTS" },
    IGNORE_WORLDMAP_SHOW_ON_MINIMAP = { "MAP_MENU_SHOW" },
    IGNORE_WORLDMAP_SHOW_ON_MINIMAP_DESC = { "MAP_MENU_SHOW" },
    SOUND_CUSTOM_FILE_INFO3 = { "SOUND_RELOAD" },
}

ns.AL = ns.AL or {}
ns.SORT = ns.SORT or {}

local function Say(msg) U.Print("RareScanner: " .. msg) end

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

-- RareScanner's locale table (the very table AceLocale keeps), or nil.
local function Locale()
    local ace = LibStub and LibStub("AceLocale-3.0", true)
    local t = ace and type(ace.apps) == "table" and ace.apps[TARGET]
    return type(t) == "table" and t or nil
end
ns.Locale = Locale

-- The % conversions of a text, in order ("sd" for "%s ... %d"); "%%" is not one.
local function Specs(s)
    local out = {}
    for c in s:gsub("%%%%", ""):gmatch("%%[-+ #0]*%d*%.?%d*(%a)") do out[#out + 1] = c end
    return table.concat(out)
end
ns.Specs = Specs

local saved, ours, swapped = {}, {}, 0 -- key -> RareScanner's English; key -> ours; how many hold ours now
local reverse = {}                -- RareScanner's English -> our Ukrainian (whole texts; Options, U.Missed)
local templates = {}              -- keys of swapped texts with % slots (Options reads baked lines back)
ns.Reverse, ns.Templates = reverse, templates

-- RareScanner's English for `key` (kept while ours is in), or nil.
local function EnglishOf(key, L)
    local en = saved[key]
    if en == nil and L then en = rawget(L, key) end
    return en
end

-- May `key` take our Ukrainian over RareScanner's English `en`? Then that Ukrainian, else nil.
local function Usable(key, en)
    local uk = ns.AL[key]
    if STAY[key] or type(uk) ~= "string" or uk == "" or type(en) ~= "string" or uk == en then return nil end
    local sort = ns.SORT[key]
    if type(sort) == "string" and sort:find("[nu]") then return nil end
    local c = Specs(en)
    if c ~= Specs(uk) then return nil end
    if type(sort) == "string" and #sort ~= #c then return nil end
    for _, inner in ipairs(INNER[key] or {}) do
        if not Usable(inner, EnglishOf(inner, Locale())) then return nil end
    end
    return uk
end
ns.Usable = Usable

-- ── The locale table ──────────────────────────────────────────────────────────────────────────

function ns.SwapIn()
    local L = Locale()
    if not L or not ns.WordsWanted() then return end
    local n = 0
    wipe(reverse)
    wipe(templates)
    wipe(ours)
    for key in pairs(ns.AL) do
        local en = EnglishOf(key, L)
        local uk = Usable(key, en)
        if uk then
            saved[key], ours[key] = en, uk
            rawset(L, key, uk)
            n = n + 1
            if Specs(en) == "" then reverse[en] = uk else templates[key] = true end
        end
    end
    swapped = n
end

-- fn(...) run with RareScanner's English in its table, then ours again: a settings table it builds then
-- holds English that Options.lua can change and put back (built with ours in, ours would stay when off).
function ns.WithEnglish(fn, ...)
    local L = Locale()
    if not L or swapped == 0 then return fn(...) end
    for key in pairs(ours) do rawset(L, key, saved[key]) end
    local res = { pcall(fn, ...) }
    for key, uk in pairs(ours) do rawset(L, key, uk) end
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, table.maxn(res))
end

function ns.SwapOut()
    local L = Locale()
    if not L then return end
    for key, en in pairs(saved) do rawset(L, key, en) end
    wipe(ours)
    swapped = 0
end

function ns.Swapped() return swapped end
function ns.English(key) return saved[key] end

-- ── On and off ────────────────────────────────────────────────────────────────────────────────

local function Apply(on)
    if on then
        U.SafeCall(ns.SwapIn)
        U.SafeCall(ns.Options.Apply)
    else
        U.SafeCall(ns.Options.Restore)
        U.SafeCall(ns.SwapOut)
    end
    U.SafeCall(ns.Fonts.Sync)
end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Fonts.Install)
    Apply(ns.WordsWanted())
end

local function End()
    Apply(false)
    U.SafeCall(ns.Fonts.Restore)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: one word alone (a name, a key), a number.
local function Keep(_, plain)
    return type(plain) == "string" and not plain:find("%s")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) or not Locale() then return end
    ready = true
    U.SafeCall(U.MissedModule, "rarescanner", { addon = TARGET, keep = Keep,
        test = function(t) return ns.Options.Translate(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("rarescanner")
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

-- The hold key: RareScanner's English while it is held, our words again after.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        Apply(ns.WordsWanted())
    end, "RareScanner")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: RareScanner не завантажено" end
    if not db.enabled then return "вимкнено (/uadd rarescanner on)" end
    return ("увімкнено: RareScanner українською; текстів наших: %d, у налаштуваннях і вікнах: %d, з нашим шрифтом: %d")
        :format(swapped, ns.Options.Count(), ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd rarescanner on - RareScanner українською",
    "/uadd rarescanner off - вимкнути, RareScanner знову англійською",
    "Назви сторінок у списку налаштувань гри можуть змінитися лише після /reload.",
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
        Say("вимкнено. RareScanner знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("rarescanner", { title = "RareScanner", Status = Status, Command = Command })
