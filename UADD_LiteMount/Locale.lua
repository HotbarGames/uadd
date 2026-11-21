-- UADD_LiteMount: our Ukrainian put into LiteMount's own locale table, in place.
-- LiteMount keeps one table, LiteMount.LM.L (the secure button `LiteMount` carries its namespace as .LM):
-- a metatable gives back the key, its English is rawset in it, keyed by constant names (LM_GROUPS).
-- Most files read L at each call, so most words follow it on their own; the copies made at load are
-- switched in Tables.lua, Copies.lua and Screen.lua.
-- Install rawsets only LM_* keys that still hold the English we saved first (nil too: LM_FALLING_ACTION has
-- no English and shows its key), Uninstall puts back only the keys that still hold our word (lessons 15, 23).
-- Never written: the keys LiteMount fills from game globals, and any key that is not LM_*: L is also read
-- with a player's group or flag names (lesson 13). A word is written only when its format specs and
-- escapes match the English; else the English shows.
local _, ns = ...
local U = UADD
local Lc = {}
ns.Locale = Lc

local SPEC = "%%[%d%$%-%+#0]*%.?%d*[%a%%]"
local ESC = { "|c", "|r", "|T", "|t", "|H", "|h", "|A", "|a", "|n", "\n" }
local NOT = "LM_NOT_FORMAT"

-- Keys never written into L: key -> why.
Lc.NEVER = {
    FAVORITES = "game global", Unknown = "game global", RIDEALONG = "game global",
    DRAGONRIDING = "game global", SKYRIDING = "game global", FLY = "game global", RUN = "game global",
    SWIM = "game global", DRIVE = "game global",
    LM_PRIORITY_DESC0 = "game global", LM_PRIORITY_DESC4 = "game global",
    LM_SUMMON_CHAT_MESSAGE = "a mount name (game name)",
    LM_SUMMON_CHAT_MESSAGE_RARITY = "a mount name (game name)",
    LM_DISABLING_MOUNT = "a mount name (game name)",
    LM_ENABLING_MOUNT = "a mount name (game name)",
    LM_AREA_FMT_S = "a game word, built at load and off on Forever",
    LM_SET_DEFAULT_MOUNT_PRIORITY_TO = "its (%s) slots hold priority names; LiteMount's code never uses it",
    LM_RARITY_FORMAT = "only a number and %: nothing to translate",
    LM_WARN_REPLACE_COND = "its slots hold rule words; LiteMount's code never uses it",
    LM_STEADY_FLIGHT = "a game name (a flight style): UALL Forever and ClassicUA name those; we write none",
    LM_USAGE = "heads its slash help, whose lines stay English",
}
-- Slot marks for the checks (CLAUDE.md "No half translations"): key -> what its slots hold.
Lc.FREE = {
    LM_ERR_BAD_ACTION = "the player's rule text",
    LM_ERR_BAD_ARGUMENTS = "the player's rule text",
    LM_ERR_BAD_CONDITION = "the player's rule text",
    LM_ERR_BAD_RULE = "the player's rule line and its error",
    LM_MOUNTSPECIAL_TIMER = "an emote command",
}
-- Ours only when its slot is ours: L holds our word or the English, set before each use (Lc.SetNot).
Lc.DYNAMIC = { [NOT] = "a condition or a mount filter: Ukrainian only when that is ours" }
-- Shown only glued to game globals (key -> them; UI/General.lua "%s (%s)" with DEFAULT, UI/MountTooltip.lua,
-- UI/MountsFilter.lua, UI/Mounts.lua counts): L holds our word only while each is Cyrillic, else the English
-- (lesson 15). tools/test_litemount_glue.py finds such lines in the installed LiteMount.
Lc.WITH_GLOBAL = { LM_EVERY_TIME = "DEFAULT", LM_SUMMON_STYLE_PRIORITY = "DEFAULT", LM_LEFT_CLICK = "MOUNT",
    LM_RIGHT_CLICK = "OPTIONS_MENU", LM_TOGGLE = "KEY_BUTTON1", LM_USABLE = { "TOTAL", "COLLECTED" } }
-- Glued to a game global, the word also shown alone: { global, between, key } (UI/General.lua "Announce via",
-- SlashCommand.lua uidebug). Switched where the line is drawn (Copies.lua), through Lc.Unglue.
Lc.GLUED = { { "CHAT", " + ", "LM_ON_SCREEN_DISPLAY" }, { "BUG_CATEGORY5", " ", "LM_DEBUGGING_ENABLED" },
    { "BUG_CATEGORY5", " ", "LM_DEBUGGING_DISABLED" } }
-- Not L keys (Tables.lua, Screen.lua): its key binding names and one button.
Lc.EXTRA = { BINDING_1 = true, BINDING_2 = true, BINDING_3 = true, BINDING_4 = true, Import = true }

local EN, UK, keys, count = {}, {}, {}, 0    -- key -> English (nil: none); key -> uk; sorted keys
local toUk, toEn, values = {}, {}, {}        -- shown English -> uk (false: two differ); uk -> English
local wrote, saved = {}, {}
local built = false

local function Specs(s)
    local out = {}
    for spec in s:gmatch(SPEC) do out[#out + 1] = spec end
    return out
end

local function Count(s, what)
    local n, at = 0, 1
    while true do
        local i = s:find(what, at, true)
        if not i then return n end
        n, at = n + 1, i + #what
    end
end

-- true when uk has the same format specs, in order, and the same escapes as en.
function Lc.Usable(en, uk)
    if type(en) ~= "string" or type(uk) ~= "string" or en == "" or uk == "" then return false end
    local a, b = Specs(en), Specs(uk)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    for _, e in ipairs(ESC) do if Count(en, e) ~= Count(uk, e) then return false end end
    return true
end

-- LiteMount's namespace and its L, or nil.
function Lc.Target()
    local b = rawget(_G, "LiteMount")
    local LM = type(b) == "table" and rawget(b, "LM")
    local L = type(LM) == "table" and rawget(LM, "L")
    if type(L) ~= "table" then return nil end
    return LM, L
end
function Lc.Found() return Lc.Target() ~= nil end

local function Build()
    if built then return end
    local _, L = Lc.Target()
    if not L then return end
    built = true
    for k, uk in pairs(ns.UK or {}) do
        if type(k) == "string" and k:find("^LM_") and not Lc.NEVER[k] then
            local en = rawget(L, k)
            if (en == nil or type(en) == "string") and Lc.Usable(en or k, uk) then
                EN[k], UK[k] = en, uk
                keys[#keys + 1] = k
                count = count + 1
            end
        end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local en, uk = EN[k] or k, UK[k]
        if toUk[en] == nil then toUk[en] = uk elseif toUk[en] ~= uk then toUk[en] = false end
        if toEn[uk] == nil then toEn[uk] = en elseif toEn[uk] ~= en then toEn[uk] = false end
        values[uk] = true
    end
end

function Lc.Count() Build() return count end
-- The English LiteMount shows for a key (its key when it has none).
function Lc.En(k) Build() return EN[k] or k end
-- Our word for a key, or nil.
function Lc.Word(k) Build() return UK[k] end
-- Our word for a whole English text, or nil; the English for a text that is still our word, or nil.
function Lc.Uk(t) Build() return type(t) == "string" and toUk[t] or nil end
function Lc.Back(t) Build() return type(t) == "string" and toEn[t] or nil end
-- true when t is one of our words.
function Lc.IsOurs(t) Build() return type(t) == "string" and values[t] == true end
-- One of the texts that are not in L (Lc.EXTRA), when it fits the English shown.
function Lc.Extra(name, en)
    local uk = ns.UK and ns.UK[name]
    if Lc.EXTRA[name] and Lc.Usable(en, uk) then return uk end
    return nil
end

-- true when the game global g (or each of a list of them) holds Cyrillic.
local function Cyr(g)
    if type(g) == "table" then
        for _, x in ipairs(g) do if not Cyr(x) then return false end end
        return #g > 0
    end
    local s = rawget(_G, g)
    return type(s) == "string" and s:find("[\208-\211][\128-\191]") ~= nil
end

-- The keys of Lc.WITH_GLOBAL: our word while its game globals are Cyrillic, else the English.
local function Globals(L)
    for k, g in pairs(Lc.WITH_GLOBAL) do
        local uk, now = wrote[k], rawget(L, k)
        if uk and (now == uk or now == EN[k]) then rawset(L, k, Cyr(g) and uk or EN[k]) end
    end
end

-- A line of Lc.GLUED with our word in it: its whole English while that global is not Cyrillic; else as it is.
function Lc.Unglue(text)
    if type(text) ~= "string" then return text end
    for _, e in ipairs(Lc.GLUED) do
        local g, uk, en = rawget(_G, e[1]), wrote[e[3]], EN[e[3]]
        if uk and en and type(g) == "string" and text == g .. e[2] .. uk and not Cyr(e[1]) then
            return g .. e[2] .. en
        end
    end
    return text
end

local function Install()
    Build()
    local _, L = Lc.Target()
    if not L then return end
    for _, k in ipairs(keys) do
        if wrote[k] == nil then
            local had = rawget(L, k)
            if had == EN[k] then
                saved[k] = { had }
                rawset(L, k, UK[k])
                wrote[k] = UK[k]
            end
        end
    end
    Globals(L)
end

local function Uninstall()
    local _, L = Lc.Target()
    if type(L) == "table" then
        for k, uk in pairs(wrote) do
            local now = rawget(L, k)
            if now == uk or (Lc.DYNAMIC[k] and now == EN[k]) then rawset(L, k, saved[k][1]) end
        end
    end
    wipe(wrote)
    wipe(saved)
end

function Lc.Written() local n = 0 for _ in pairs(wrote) do n = n + 1 end return n end

-- "Not %s": our word when the text in its slot is ours, else the English, so the line is whole.
-- Called right before LiteMount reads it (Tables.lua, after each condition it shows).
function Lc.SetNot(ours)
    local uk = wrote[NOT]
    if not uk then return end
    local _, L = Lc.Target()
    if not L then return end
    local now = rawget(L, NOT)
    if now == uk or now == EN[NOT] then rawset(L, NOT, ours and uk or EN[NOT]) end
end

-- Our words in L while they are wanted, the English otherwise.
function Lc.Sync()
    if ns.WordsWanted() then Install() else Uninstall() end
end
function Lc.Restore() Uninstall() end
