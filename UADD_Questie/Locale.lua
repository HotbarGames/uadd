-- Questie's own menus and messages in Ukrainian, through Questie's documented hook:
-- the QUESTIE_LOCALES_OVERRIDE global (Questie/Localization/l10n.lua, lines 11-16 and 44-73).
--
-- We set it at our ADDON_LOADED. Questie reads it later, at PLAYER_LOGIN
-- (Modules/QuestieInit.lua:169). Questie then adds "ukUA" to its languages, copies our strings into
-- l10n.translations[key].ukUA, makes ukUA its language (unless the player picked another one in
-- Questie's options) and tells QuestieDB to use ukUA too (QuestieInit.lua:191-193).
-- With UADD switched off we do not set the global, so after /reload Questie is English again.

local _, ns = ...
local L = {}
ns.Locale = L

L.LOCALE = "ukUA"
L.LOCALE_NAME = "Українська"

function L.Questie_l10n()
    local ok, mod = pcall(function()
        return QuestieLoader and QuestieLoader:ImportModule("l10n")
    end)
    if ok and type(mod) == "table" and type(mod.translations) == "table" then return mod end
    return nil
end

-- ── Safety checks for translated text ─────────────────────────────────────────────────────────

-- Questie runs string.format(translation, ...) with the English key's arguments. A translation
-- must therefore ask for the same values in the same order. Returns the list of conversions
-- ("s", "d", ...) or nil when the text has a broken % sign.
local VALID = "cdeEfgGioqsuxX"
local function Specs(s)
    local out, i = {}, 1
    while true do
        local at = s:find("%", i, true)
        if not at then return out end
        if s:sub(at + 1, at + 1) == "%" then
            i = at + 2
        else
            local flags, conv = s:match("^([-+ #0]*%d*%.?%d*)(%a)", at + 1)
            if not conv or not VALID:find(conv, 1, true) then return nil end
            out[#out + 1] = conv
            i = at + 1 + #flags + 1
        end
    end
end

-- How many of each |c |r |T |t |H |h |n escape a text has, as one comparable string.
local ESCAPES = { "c", "r", "T", "t", "H", "h", "n" }
local function EscapeCounts(s)
    local parts = {}
    for i, e in ipairs(ESCAPES) do
        local _, n = s:gsub("|" .. e, "")
        parts[i] = n
    end
    return table.concat(parts, ",")
end

-- true when `uk` can stand in for `key` without breaking Questie.
function L.Compatible(key, uk)
    if type(key) ~= "string" or type(uk) ~= "string" or uk == "" then return false end
    local a, b = Specs(key), Specs(uk)
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return EscapeCounts(key) == EscapeCounts(uk)
end

-- A place name (zone) is shown with l10n(name) and no arguments, so it must not hold a %.
function L.SafeName(uk)
    return type(uk) == "string" and uk ~= "" and not uk:find("%", 1, true)
end

-- ── Set up the override, before Questie reads it ──────────────────────────────────────────────

L.stats = { strings = 0, skipped = 0, unknown = 0, zones = 0 }

-- zones: cached { [englishName] = ukrainian } from an earlier session (may be nil).
-- Returns the state: "on", "conflict" (another addon set the global first) or "no-questie".
function L.Prepare(zones)
    local l10n = L.Questie_l10n()
    if not l10n then
        L.state = "no-questie"
        return L.state
    end
    if QUESTIE_LOCALES_OVERRIDE ~= nil then
        local other = type(QUESTIE_LOCALES_OVERRIDE) == "table" and QUESTIE_LOCALES_OVERRIDE.locale
        L.state, L.otherLocale = "conflict", tostring(other or "?")
        return L.state
    end
    local stats, t = L.stats, {}
    for key, uk in pairs(ns.uiStrings or {}) do
        if type(l10n.translations[key]) ~= "table" then
            stats.unknown = stats.unknown + 1       -- a key this Questie version does not have
        elseif L.Compatible(key, uk) then
            t[key] = uk
            stats.strings = stats.strings + 1
        else
            stats.skipped = stats.skipped + 1
        end
    end
    for name, uk in pairs(type(zones) == "table" and zones or {}) do
        if type(name) == "string" and t[name] == nil and L.SafeName(uk) and not name:find("%", 1, true) then
            if l10n.translations[name] == nil then l10n.translations[name] = { enUS = true } end
            if type(l10n.translations[name]) == "table" then
                t[name] = uk
                stats.zones = stats.zones + 1
            end
        end
    end
    QUESTIE_LOCALES_OVERRIDE = { locale = L.LOCALE, localeName = L.LOCALE_NAME, translations = t }
    L.override = QUESTIE_LOCALES_OVERRIDE
    L.state = "on"
    return L.state
end

-- true when Questie is showing our language right now, or shows English only for as long as
-- the show-original key is held (Original.lua).
function L.IsActive()
    local l10n = L.Questie_l10n()
    if not (l10n and l10n.GetUILocale) then return false end
    local ok, current = pcall(l10n.GetUILocale, l10n)
    if ok and current == "enUS" and ns.Original and ns.Original.held then return true end
    return ok and current == L.LOCALE
end

-- Zone names found this session: written straight into l10n.translations[name].ukUA,
-- never over a Ukrainian text that is already there. Returns true when it wrote.
function L.AddZone(name, uk)
    local l10n = L.Questie_l10n()
    if not l10n or type(name) ~= "string" or not L.SafeName(uk) or name:find("%", 1, true) then return false end
    local entry = l10n.translations[name]
    if entry == nil then
        l10n.translations[name] = { enUS = true, [L.LOCALE] = uk }
    elseif type(entry) == "table" then
        if type(entry[L.LOCALE]) == "string" then return false end
        entry[L.LOCALE] = uk
    else
        return false
    end
    L.stats.zones = L.stats.zones + 1
    return true
end

-- Every English place name Questie shows, without repeats.
function L.ZoneNames()
    local l10n, names, seen = L.Questie_l10n(), {}, {}
    local function add(name)
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    if l10n then
        for _, list in pairs(type(l10n.zoneLookup) == "table" and l10n.zoneLookup or {}) do
            if type(list) == "table" then
                for _, name in pairs(list) do add(name) end
            end
        end
        for _, name in pairs(type(l10n.continentLookup) == "table" and l10n.continentLookup or {}) do add(name) end
    end
    table.sort(names)
    return names
end

-- /uadd questie off, right now: Questie goes back to the client's language (English on an
-- English client). Some text keeps Ukrainian until /reload; the caller says so.
function L.SwitchOff()
    local l10n = L.Questie_l10n()
    if not (l10n and l10n.SetUILocale and L.IsActive()) then return false end
    pcall(l10n.SetUILocale, l10n, GetLocale and GetLocale() or "enUS")
    local ok, current = pcall(l10n.GetUILocale, l10n)
    local db = _G.LibQuestieDB
    if ok and db and db.l10n and db.l10n.SetLocale then pcall(db.l10n.SetLocale, current) end
    return true
end
